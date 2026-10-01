import CryptoKit
import Darwin
import Foundation

nonisolated(unsafe) private var shutdownRequested = false

enum CLIApplication {
    static func run(_ options: CLIOptions) throws {
        let interfaces = try NetworkInterface.discover()
        let selected = try options.networkInterface(from: interfaces)
        let store = try TerminalPassword.unlockHistory(at: options.historyDirectory)
        let isChat = options.command == .chat
        let lease = try RoleLease(directory: options.historyDirectory, role: isChat ? "chat" : "receive")
        defer { withExtendedLifetime(lease) {} }
        var session = try ChatSession(role: isChat ? .chat : .backgroundReceiver,
            localIP: selected.ip, ownIPs: Set(interfaces.map(\.ip)), store: store)
        let codec = PacketCodec(key: HushConfig.communicationKey)
        let receiver = try UDPTransport(port: options.port)
        let socket = try UDPTransport(port: 0, bindIP: selected.ip)
        var sender = MessageSender { try socket.send($0, to: selected.broadcastIP, port: options.port) }
        shutdownRequested = false
        signal(SIGINT) { _ in shutdownRequested = true }
        signal(SIGTERM) { _ in shutdownRequested = true }
        signal(SIGPIPE, SIG_IGN)
        if isChat { signal(SIGHUP) { _ in shutdownRequested = true } }
        else { signal(SIGHUP, SIG_IGN) }
        let terminal = isChat ? try TerminalMode() : nil
        defer { terminal?.restore() }
        let view = isChat ? TerminalChatView() : nil
        if let view {
            view.notice("Hush \(HushConfig.version) — 내 IP \(selected.ip), /quit으로 종료")
            for record in try store.load() { view.showMessage(record, isNew: false) }
        } else {
            print("수신 중 (PID \(getpid())): \(selected.name) \(selected.ip):\(options.port), 기록: \(store.url.path)")
        }
        var quitting = false
        var lastRefresh: TimeInterval = 0
        var previousStatus = ""
        while !shutdownRequested && (!quitting || sender.hasPending) {
            let uptime = ProcessInfo.processInfo.systemUptime
            let now = Date()
            if session.shouldSendHeartbeat(at: now), !quitting {
                do {
                    try socket.send(codec.encode(.heartbeat), to: selected.broadcastIP, port: options.port)
                    session.recordHeartbeatSent(at: now)
                } catch { view?.notice("heartbeat 송신 실패: \(error)") }
            }
            do { try sender.sendDue(at: uptime) }
            catch { view?.notice("메시지 송신 실패: \(error)") }
            let status = "\(session.peerIP ?? ""):\(session.isPeerOnline(at: now))"
            if status != previousStatus {
                view?.showStatus(ip: session.peerIP, online: session.isPeerOnline(at: now))
                previousStatus = status
            }
            if uptime - lastRefresh >= 0.5 {
                let refreshed = try session.refreshHistory()
                for record in refreshed { view?.showMessage(record, isNew: true) }
                lastRefresh = uptime
            }
            let remaining = sender.nextDeadline.map { max(0, $0 - ProcessInfo.processInfo.systemUptime) } ?? 0.1
            var events = [pollfd(fd: receiver.descriptor, events: Int16(POLLIN), revents: 0)]
            if isChat && !quitting { events.append(pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)) }
            let result = poll(&events, nfds_t(events.count), Int32(min(remaining * 1_000, 100)))
            if result < 0 {
                if errno == EINTR { continue }
                throw SocketFailure("이벤트 대기")
            }
            if events[0].revents & Int16(POLLIN) != 0 {
                for _ in 0..<64 {
                    guard let received = try receiver.receive() else { break }
                    guard let packet = try? codec.decode(received.data, senderIP: received.senderIP) else { continue }
                    switch packet {
                    case .heartbeat: session.receiveHeartbeat(from: received.senderIP, at: Date())
                    case .message(let message):
                        if let record = try session.receiveMessage(message) { view?.showMessage(record, isNew: true) }
                    }
                }
            }
            if events.count > 1, events[1].revents & Int16(POLLIN | POLLHUP) != 0, let view {
                var bytes = [UInt8](repeating: 0, count: 1_024)
                let count = Darwin.read(STDIN_FILENO, &bytes, bytes.count)
                if count == 0 { quitting = true }
                else if count < 0 { if errno != EINTR { throw SocketFailure("채팅 입력 읽기") } }
                else {
                    for action in view.consume(Array(bytes.prefix(count))) {
                        switch action {
                        case .quit: quitting = true
                        case .submit(let content):
                            guard !quitting else { continue }
                            guard content.utf8.count <= 8_192 else { view.notice("메시지는 UTF-8 기준 8192바이트까지 보낼 수 있습니다"); continue }
                            let (message, plan) = try session.prepareSend(content: content, at: Date(), contentHash: PacketCodec.contentHash(content))
                            let packet = try codec.encode(.message(message))
                            sender.enqueue(packet, plan: plan, at: ProcessInfo.processInfo.systemUptime)
                            view.showMessage(RecordedMessage(message: message, isOutgoing: true), isNew: true)
                        }
                    }
                }
            }
        }
        view?.finish()
    }
}
