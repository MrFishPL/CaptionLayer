import AppKit

enum AppConfig {
    static let panelSize = NSSize(width: 460, height: 64)
    static let visibleLines: CGFloat = 1
    static let bottomPadding: CGFloat = 10
    static let topDeadArea: CGFloat = 40
    static let pauseForBlankLine: TimeInterval = 1.2
    static let displayCharLimit: Int = 220
}
