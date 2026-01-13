import AppKit
import Carbon

enum AppConfig {
    static let panelSize = NSSize(width: 460, height: 84)
    static let visibleLines: CGFloat = 3
    static let bottomPadding: CGFloat = 10
    static let topDeadArea: CGFloat = 40
    static let pauseForBlankLine: TimeInterval = 1.2
    static let clearHotKey = HotKeyDefinition(
        id: 1,
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: UInt32(cmdKey | kEventKeyModifierFnMask)
    )
    static let tabHotKey = HotKeyDefinition(
        id: 2,
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(cmdKey | kEventKeyModifierFnMask)
    )
}
