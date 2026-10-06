import AppKit
import CryptoKit
import Darwin
import Foundation

nonisolated(unsafe) private var shutdownRequested = false

enum CLIApplication {
    static func run(_ options: CLIOptions) throws {
        let updater = try UpdateRuntime.configured()
        if options.command == .receive { return try runReceiver(options: options, updater: updater) }
        let interfaces = try NetworkInterface.discover()
        let selected = try options.networkInterface(from: interfaces, preference: .current())
        let store = try TerminalPassword.unlockHistory(at: options.historyDirectory)
        try runChat(options: options, updater: updater, store: store, interfaces: interfaces, selected: selected)
    }

    static func runMenu(_ options: CLIOptions) throws {
        let updater = try UpdateRuntime.configured()
        let store = try TerminalPassword.unlockHistory(at: options.historyDirectory)
        let menu = MainMenu()
        defer { FileHandle.standardOutput.write(Data("\n".utf8)) }
        // 수신함 열쇠가 준비된 뒤 로그인 항목으로 수신기를 등록합니다.
        let agentExecutable = receiverAgentExecutable(options)
        if let agentExecutable {
            do { try ReceiverAgent.ensureRegistered(executable: agentExecutable) }
            catch { menu.notice("\(error)") }
        }
        while true {
            // 메뉴도 채팅처럼 Ctrl-C와 터미널 종료에 끝냅니다.
            configureSignals(isChat: true)
            TerminalPalette.reload(from: options.historyDirectory)
            let preference = NetworkPreference.current()
            let interfaces = (try? NetworkInterface.discover()) ?? []
            let network = Result { try options.networkInterface(from: interfaces, preference: preference) }
            let selected = try? network.get()
            if case .failure(let error) = network { menu.notice("\(error)") }
            let choice = try readKey(after: {
                menu.show(network: selected, isWiFi: selected.map { preference.wifiNames.contains($0.name) } ?? false,
                    receiverRunning: agentExecutable.map { _ in ReceiverAgent.isRunning() })
            }, until: MainMenu.choice(for:))
            guard let choice else { return }
            switch choice {
            case .history:
                guard try readKey(after: { TerminalHistoryView().show(try store.load()) }, until: { $0 }) != nil else { return }
            case .chat:
                guard let selected else { continue }
                do {
                    try runChat(options: options, updater: updater, store: store, interfaces: interfaces, selected: selected)
                } catch { menu.notice("\(error)") }
                if shutdownRequested { return }
            case .quit: return
            }
        }
    }

    // 테스트용 기록 위치나 개발 빌드는 로그인 항목으로 등록하지 않습니다.
    private static func receiverAgentExecutable(_ options: CLIOptions) -> URL? {
        guard options.historyDirectory.standardizedFileURL == CLIOptions.defaultHistoryDirectory.standardizedFileURL,
              let executable = Bundle.main.executableURL?.resolvingSymlinksInPath(),
              !executable.pathComponents.contains(".build") else { return nil }
        return executable
    }

    // 화면을 그리기 전에 입력 모드를 바꿔, 화면을 보고 바로 누른 키가 버려지지 않게 합니다.
    // 받아들이는 키가 올 때까지 Enter 없이 읽으며, 종료 신호를 받으면 nil을 반환합니다.
    private static func readKey<Value>(after show: () throws -> Void, until accept: (UInt8) -> Value?) throws -> Value? {
        let terminal = try TerminalMode()
        defer { terminal.restore() }
        try show()
        while !shutdownRequested {
            var event = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            let result = poll(&event, 1, 100)
            if result < 0 {
                if errno == EINTR { continue }
                throw SocketFailure("메뉴 입력 대기")
            }
            guard result > 0 else { continue }
            var byte: UInt8 = 0
            let count = Darwin.read(STDIN_FILENO, &byte, 1)
            if count < 0 {
                if errno == EINTR { continue }
                throw SocketFailure("메뉴 입력 읽기")
            }
            if let value = accept(count == 0 ? 4 : byte) { return value }
        }
        return nil
    }

    private static func runChat(options: CLIOptions, updater: UpdateRuntime?, store: HistoryStore,
                                interfaces: [NetworkInterface], selected: NetworkInterface) throws {
        let lease = try RoleLease(directory: options.historyDirectory, role: "chat")
        defer { withExtendedLifetime(lease) {} }
        var session = try ChatSession(role: .chat, localIP: selected.ip, ownIPs: Set(interfaces.map(\.ip)), store: store)
        let codec = PacketCodec(key: HushConfig.communicationKey)
        let receiver = try UDPTransport(port: options.port)
        let socket = try UDPTransport(port: 0, bindIP: selected.ip)
        var sender = MessageSender { try socket.send($0, to: selected.broadcastIP, port: options.port) }
        configureSignals(isChat: true)
        let terminal = try TerminalMode()
        defer { terminal.restore() }
        terminal.enableFocusReporting()
        let view = TerminalChatView()
        view.notice("Hush \(HushConfig.version) — 내 IP \(selected.ip), /help로 명령 보기")
        for record in try store.load() { view.showMessage(record, isNew: false) }
        var quitting = false
        var lastRefresh: TimeInterval = 0
        var lastPaletteCheck: TimeInterval = 0
        var previousStatus = ""
        var acknowledged: Set<MessageIdentity> = []
        while !shutdownRequested && (!quitting || sender.hasPending) {
            let uptime = ProcessInfo.processInfo.systemUptime
            let now = Date()
            try checkForUpdates(updater, at: uptime, terminal: terminal, view: view)
            if !quitting {
                sendHeartbeatIfNeeded(session: &session, at: now, codec: codec, socket: socket,
                    network: selected, port: options.port, view: view)
            }
            do { try sender.sendDue(at: uptime) }
            catch { view.notice("메시지 송신 실패: \(error)") }
            // 메뉴 막대에서 바꾼 글자 색을 새로 나오는 줄과 입력 줄부터 반영합니다.
            if uptime - lastPaletteCheck >= 0.5 {
                if TerminalPalette.reload(from: options.historyDirectory) { view.redraw() }
                lastPaletteCheck = uptime
            }
            try refreshDisplay(session: &session, at: now, uptime: uptime, view: view,
                previousStatus: &previousStatus, lastRefresh: &lastRefresh)
            let remaining = sender.nextDeadline.map { max(0, $0 - ProcessInfo.processInfo.systemUptime) } ?? 0.1
            var events = [pollfd(fd: receiver.descriptor, events: Int16(POLLIN), revents: 0)]
            if !quitting { events.append(pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)) }
            let result = poll(&events, nfds_t(events.count), Int32(min(remaining * 1_000, 100)))
            if result < 0 {
                if errno == EINTR { continue }
                throw SocketFailure("이벤트 대기")
            }
            if events[0].revents & Int16(POLLIN) != 0 {
                try receivePackets(receiver, codec: codec, session: &session, view: view)
            }
            if events.count > 1, events[1].revents & Int16(POLLIN | POLLHUP) != 0 {
                let draft = view.draft
                try handleInput(view: view, session: &session, sender: &sender, codec: codec, quitting: &quitting)
                if view.draft != draft {
                    sendTypingIfNeeded(session: &session, composing: view.composingMessage, at: Date(), codec: codec,
                        socket: socket, network: selected, port: options.port)
                }
            }
            if view.focused && !quitting {
                let unread = view.displayedIncoming.subtracting(acknowledged)
                if !unread.isEmpty {
                    try UnreadStore.markRead(unread, in: options.historyDirectory)
                    acknowledged.formUnion(unread)
                }
            }
            view.finishReadCheck()
        }
        view.finish()
    }

    // 백그라운드 수신기는 비밀번호와 터미널 없이 실행하며, 받은 메시지를 공개키로 봉인해 수신함에 쌓기만 합니다.
    private static func runReceiver(options: CLIOptions, updater: UpdateRuntime?) throws {
        guard options.menuBar else { return try receiveLoop(options: options, updater: updater, onUnread: nil) }
        // 메뉴 막대는 메인 스레드에서 그리므로 수신 루프는 별도 스레드에서 실행하고, 루프가 끝나면 프로세스를 끝냅니다.
        _ = try InboxWriter(directory: options.historyDirectory)
        MainActor.assumeIsolated {
            NSApplication.shared.setActivationPolicy(.accessory)
            let executable = Bundle.main.executableURL?.resolvingSymlinksInPath()
            let directory = options.historyDirectory
            MenuBarIndicator.current = MenuBarIndicator(openHush: {
                guard let executable else { return }
                do { try TerminalLauncher.openHush(executable: executable, directory: directory) }
                catch { log("Hush 열기 실패: \(error)") }
            }, textColor: { SettingsStore.textColor(in: directory) }, setTextColor: { color in
                do { try SettingsStore.save(textColor: color, in: directory) }
                catch { log("글자 색 저장 실패: \(error)") }
            })
        }
        Thread {
            do {
                try receiveLoop(options: options, updater: updater) { unread in
                    Task { @MainActor in MenuBarIndicator.current?.show(unread: unread) }
                }
                exit(0)
            } catch {
                log("수신기 종료: \(error)")
                exit(1)
            }
        }.start()
        MainActor.assumeIsolated { NSApplication.shared.run() }
    }

    private static func receiveLoop(options: CLIOptions, updater: UpdateRuntime?, onUnread: ((Int) -> Void)?) throws {
        let store = try InboxWriter(directory: options.historyDirectory)
        let lease = try RoleLease(directory: options.historyDirectory, role: "receive")
        defer { withExtendedLifetime(lease) {} }
        var session = try ChatSession(role: .backgroundReceiver, localIP: "", ownIPs: [], store: store)
        let codec = PacketCodec(key: HushConfig.communicationKey)
        let receiver = try UDPTransport(port: options.port)
        configureSignals(isChat: false)
        log("수신 중 (PID \(getpid())): 포트 \(options.port), 수신함: \(store.url.path)")
        var ownIPs: Set<String> = []
        var lastDiscovery: TimeInterval?
        var badge = UnreadBadge()
        var lastPendingCheck: TimeInterval?
        while !shutdownRequested {
            let uptime = ProcessInfo.processInfo.systemUptime
            try checkForUpdates(updater, at: uptime, terminal: nil, view: nil)
            if let onUnread, lastPendingCheck.map({ uptime - $0 >= 0.5 }) ?? true {
                if let unread = badge.update(pending: try UnreadStore.count(in: options.historyDirectory), at: uptime) { onUnread(unread) }
                lastPendingCheck = uptime
            }
            // 네트워크가 바뀌어도 내 메시지를 거르도록 내 IP 목록을 주기적으로 다시 읽습니다.
            if lastDiscovery.map({ uptime - $0 >= 5 }) ?? true {
                ownIPs = Set(((try? NetworkInterface.discover()) ?? []).map(\.ip))
                lastDiscovery = uptime
            }
            var event = pollfd(fd: receiver.descriptor, events: Int16(POLLIN), revents: 0)
            let result = poll(&event, 1, 100)
            if result < 0 {
                if errno == EINTR { continue }
                throw SocketFailure("이벤트 대기")
            }
            if event.revents & Int16(POLLIN) != 0 {
                try receivePackets(receiver, codec: codec, session: &session, view: nil, ignoring: ownIPs)
            }
        }
    }

    // 터미널이 닫힌 뒤에도 쓰기 오류로 종료되지 않도록 표준 입출력 함수로 출력하며, 로그 파일에는 색을 넣지 않습니다.
    private static func log(_ text: String) {
        print(isatty(STDOUT_FILENO) == 1 ? TerminalChatView.styled(text) : text)
        fflush(stdout)
    }

    private static func configureSignals(isChat: Bool) {
        shutdownRequested = false
        signal(SIGINT) { _ in shutdownRequested = true }
        signal(SIGTERM) { _ in shutdownRequested = true }
        signal(SIGPIPE, SIG_IGN)
        if isChat { signal(SIGHUP) { _ in shutdownRequested = true } }
        else { signal(SIGHUP, SIG_IGN) }
    }

    private static func checkForUpdates(_ updater: UpdateRuntime?, at uptime: TimeInterval,
                                        terminal: TerminalMode?, view: TerminalChatView?) throws {
        var installed: InstalledExecutable?
        do { installed = try updater?.poll(at: uptime) }
        catch {
            if let view { view.notice("업데이트 확인·적용 실패: \(error)") }
            // 10분마다 반복될 수 있으므로 로그에는 네트워크 오류의 요약만 남깁니다.
            else { log("업데이트 확인·적용 실패: \((error as? URLError)?.localizedDescription ?? "\(error)")") }
        }
        if let installed {
            view?.notice("새 버전 적용 완료. 재시작 후 비밀번호를 다시 입력하세요")
            terminal?.restore()
            try ProcessRestart.restart(installed, arguments: Array(CommandLine.arguments.dropFirst()))
        }
    }

    private static func sendHeartbeatIfNeeded(session: inout ChatSession, at now: Date,
                                              codec: PacketCodec, socket: UDPTransport,
                                              network: NetworkInterface, port: UInt16, view: TerminalChatView?) {
        guard session.shouldSendHeartbeat(at: now) else { return }
        do {
            try socket.send(codec.encode(.heartbeat), to: network.broadcastIP, port: port)
            session.recordHeartbeatSent(at: now)
        } catch { view?.notice("heartbeat 송신 실패: \(error)") }
    }

    // 입력 중 알림은 놓쳐도 상대 화면에서 만료되므로, 송신 실패를 키마다 안내하지 않습니다.
    private static func sendTypingIfNeeded(session: inout ChatSession, composing: Bool, at now: Date,
                                           codec: PacketCodec, socket: UDPTransport,
                                           network: NetworkInterface, port: UInt16) {
        guard let signal = session.typingSignal(composing: composing, at: now),
              let packet = try? codec.encode(.typing(signal)),
              (try? socket.send(packet, to: network.broadcastIP, port: port)) != nil else { return }
        session.recordTypingSent(signal, at: now)
    }

    private static func refreshDisplay(session: inout ChatSession, at now: Date, uptime: TimeInterval,
                                       view: TerminalChatView?, previousStatus: inout String,
                                       lastRefresh: inout TimeInterval) throws {
        let status = "\(session.peerIP ?? ""):\(session.isPeerOnline(at: now))"
        if status != previousStatus {
            view?.showStatus(ip: session.peerIP, online: session.isPeerOnline(at: now))
            previousStatus = status
        }
        view?.showPeerTyping(session.isPeerTyping(at: now))
        if uptime - lastRefresh >= 0.5 {
            let refreshed = try session.refreshHistory()
            for record in refreshed { view?.showMessage(record, isNew: true) }
            lastRefresh = uptime
        }
    }

    private static func receivePackets(_ receiver: UDPTransport, codec: PacketCodec,
                                       session: inout ChatSession, view: TerminalChatView?,
                                       ignoring ownIPs: Set<String> = []) throws {
        for _ in 0..<64 {
            guard let received = try receiver.receive() else { break }
            guard !ownIPs.contains(received.senderIP),
                  let packet = try? codec.decode(received.data, senderIP: received.senderIP) else { continue }
            switch packet {
            case .heartbeat: session.receiveHeartbeat(from: received.senderIP, at: Date())
            case .typing(let signal): session.receiveTyping(signal, from: received.senderIP, at: Date())
            case .message(let message):
                if let record = try session.receiveMessage(message) { view?.showMessage(record, isNew: true) }
            }
        }
    }

    private static func handleInput(view: TerminalChatView, session: inout ChatSession,
                                    sender: inout MessageSender, codec: PacketCodec, quitting: inout Bool) throws {
        var bytes = [UInt8](repeating: 0, count: 1_024)
        let count = Darwin.read(STDIN_FILENO, &bytes, bytes.count)
        if count == 0 { quitting = true }
        else if count < 0 { if errno != EINTR { throw SocketFailure("채팅 입력 읽기") } }
        else {
            for action in view.consume(Array(bytes.prefix(count))) {
                switch action {
                case .quit: quitting = true
                case .help: view.showHelp()
                case .clear:
                    view.clearScreen()
                    view.showStatus(ip: session.peerIP, online: session.isPeerOnline(at: Date()))
                case .unknownCommand(let command): view.notice("알 수 없는 명령: \(command) (/help로 명령 보기)")
                case .submit(let content):
                    guard !quitting else { continue }
                    try submitMessage(content, session: &session, sender: &sender, codec: codec, view: view)
                }
            }
        }
    }

    private static func submitMessage(_ content: String, session: inout ChatSession,
                                      sender: inout MessageSender, codec: PacketCodec, view: TerminalChatView) throws {
        guard content.utf8.count <= 8_192 else {
            view.notice("메시지는 UTF-8 기준 8192바이트까지 보낼 수 있습니다")
            return
        }
        let (message, plan) = try session.prepareSend(content: content, at: Date(), contentHash: PacketCodec.contentHash(content))
        let packet = try codec.encode(.message(message))
        sender.enqueue(packet, plan: plan, at: ProcessInfo.processInfo.systemUptime)
        view.showMessage(RecordedMessage(message: message, isOutgoing: true), isNew: true)
    }
}
