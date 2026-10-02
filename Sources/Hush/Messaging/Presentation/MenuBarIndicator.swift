import AppKit

// 백그라운드 수신기의 메뉴 막대 표시입니다. 평소에는 흑백 말풍선, 안 읽은 메시지가 있으면 빨간 배지로 건수만 보여 줍니다.
@MainActor
final class MenuBarIndicator: NSObject {
    static var current: MenuBarIndicator?
    private let item: NSStatusItem
    private let summary = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let openHush: () -> Void

    init(openHush: @escaping () -> Void) {
        self.openHush = openHush
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        let menu = NSMenu()
        summary.isEnabled = false
        menu.addItem(summary)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Hush 열기", action: #selector(open(_:)), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        item.menu = menu
        show(unread: 0)
    }

    func show(unread: Int) {
        let text = Self.summary(unread: unread)
        summary.title = text
        item.button?.image = unread == 0 ? Self.idleIcon() : Self.unreadIcon(unread: unread)
        item.button?.toolTip = "Hush · \(text)"
        item.button?.setAccessibilityLabel("Hush \(text)")
    }

    nonisolated static func summary(unread: Int) -> String {
        unread == 0 ? "새 메시지 없음" : "새 메시지 \(unread)건"
    }

    nonisolated static func badgeText(unread: Int) -> String {
        unread > 9 ? "9+" : "\(unread)"
    }

    @objc private func open(_ sender: Any?) { openHush() }

    // 메뉴 막대의 밝기에 맞춰 시스템이 색을 정하는 흑백 아이콘입니다.
    private static func idleIcon() -> NSImage? {
        let image = NSImage(systemSymbolName: "bubble.left", accessibilityDescription: "Hush")?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        image?.isTemplate = true
        return image
    }

    // 채운 말풍선 오른쪽 위에 빨간 원과 흰 숫자를 그린 컬러 아이콘이며, 말풍선은 평소 아이콘과 같은 크기로 그립니다.
    private static func unreadIcon(unread: Int) -> NSImage {
        let text = badgeText(unread: unread)
        let bubble = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                .applying(.init(paletteColors: [NSColor.labelColor])))
        let bubbleSize = bubble?.size ?? NSSize(width: 17, height: 16)
        let badgeHeight: CGFloat = 12
        let badgeWidth: CGFloat = text.count > 1 ? 17 : badgeHeight
        let size = NSSize(width: bubbleSize.width + badgeWidth / 2, height: bubbleSize.height + badgeHeight / 3)
        let image = NSImage(size: size, flipped: false) { _ in
            bubble?.draw(in: NSRect(origin: .zero, size: bubbleSize))
            let badge = NSRect(x: size.width - badgeWidth, y: size.height - badgeHeight, width: badgeWidth, height: badgeHeight)
            NSColor.systemRed.setFill()
            NSBezierPath(roundedRect: badge, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2).fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: NSColor.white,
            ]
            let label = NSAttributedString(string: text, attributes: attributes)
            let labelSize = label.size()
            label.draw(at: NSPoint(x: badge.midX - labelSize.width / 2, y: badge.midY - labelSize.height / 2))
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Hush \(summary(unread: unread))"
        return image
    }
}
