import AppKit

@main
struct TranscribtionApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let panelSize = AppConfig.panelSize
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let origin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - panelSize.height
        )

        let panel = NotchPanel(frame: NSRect(origin: origin, size: panelSize))
        let notchView = NotchView(frame: NSRect(origin: .zero, size: panelSize))
        panel.contentView = notchView
        panel.makeKeyAndOrderFront(nil)

        let transcription = TranscriptionController(notchView: notchView)
        transcription.start()

        let hotKeyManager = HotKeyManager(
            definitions: [AppConfig.clearHotKey, AppConfig.tabHotKey]
        ) { hotKeyID in
            switch hotKeyID {
            case AppConfig.clearHotKey.id:
                transcription.clearTranscription()
            case AppConfig.tabHotKey.id:
                transcription.insertTabMarker()
            default:
                break
            }
        }
        _ = hotKeyManager

        app.run()
    }
}
