import AppKit

// 백그라운드 수신기의 메뉴 막대 표시입니다. 평소에는 흑백 말풍선, 안 읽은 메시지가 있으면 빨간 배지로 건수만 보여 주고,
// 메뉴에서 Hush 열기와 글자 색 선택을 제공합니다.
@MainActor
final class MenuBarIndicator: NSObject, NSMenuDelegate {
    static var current: MenuBarIndicator?
    private let item: NSStatusItem
    private let summary = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let colorMenu = NSMenu()
    private let openHush: () -> Void
    private let textColor: () -> TextColor
    private let setTextColor: (TextColor) -> Void

    init(openHush: @escaping () -> Void, textColor: @escaping () -> TextColor, setTextColor: @escaping (TextColor) -> Void) {
        self.openHush = openHush
        self.textColor = textColor
        self.setTextColor = setTextColor
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        let menu = NSMenu()
        summary.isEnabled = false
        menu.addItem(summary)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Hush 열기", action: #selector(open(_:)), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let colors = NSMenuItem(title: "글자 색", action: nil, keyEquivalent: "")
        for (index, preset) in TerminalPalette.presets.enumerated() {
            let choice = NSMenuItem(title: preset.title, action: #selector(choosePreset(_:)), keyEquivalent: "")
            choice.target = self
            choice.tag = index
            choice.image = Self.swatch(preset.swatch)
            colorMenu.addItem(choice)
        }
        colorMenu.addItem(.separator())
        let custom = NSMenuItem(title: "직접 고르기…", action: #selector(openPalette(_:)), keyEquivalent: "")
        custom.target = self
        colorMenu.addItem(custom)
        colorMenu.delegate = self
        colors.submenu = colorMenu
        menu.addItem(colors)
        item.menu = menu
        show(unread: 0)
    }

    // 메뉴를 열 때마다 설정 파일을 다시 읽어 지금 색에 체크를 붙입니다.
    func menuWillOpen(_ menu: NSMenu) {
        let current = textColor()
        for choice in menu.items where choice.action == #selector(choosePreset(_:)) {
            choice.state = TerminalPalette.presets[choice.tag].color == current ? .on : .off
        }
        if let custom = menu.items.last {
            if case .rgb = current { custom.state = .on } else { custom.state = .off }
        }
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

    @objc private func choosePreset(_ sender: NSMenuItem) {
        setTextColor(TerminalPalette.presets[sender.tag].color)
    }

    // 손을 뗄 때만 색을 받아 설정 파일을 너무 자주 쓰지 않습니다.
    @objc private func openPalette(_ sender: Any?) {
        let panel = NSColorPanel.shared
        panel.isContinuous = false
        if case .rgb(let red, let green, let blue) = textColor() {
            panel.color = NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
        }
        panel.setTarget(self)
        panel.setAction(#selector(paletteChanged(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func paletteChanged(_ sender: NSColorPanel) {
        guard let color = sender.color.usingColorSpace(.sRGB) else { return }
        let component = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        setTextColor(.rgb(red: component(color.redComponent), green: component(color.greenComponent), blue: component(color.blueComponent)))
    }

    // 정해 둔 색의 견본 원이며, 터미널 기본색은 빈 원으로 그립니다.
    private static func swatch(_ color: (red: Int, green: Int, blue: Int)?) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            if let color {
                NSColor(srgbRed: CGFloat(color.red) / 255, green: CGFloat(color.green) / 255, blue: CGFloat(color.blue) / 255, alpha: 1).setFill()
                circle.fill()
            } else {
                NSColor.labelColor.setStroke()
                circle.lineWidth = 1
                circle.stroke()
            }
            return true
        }
        return image
    }

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
