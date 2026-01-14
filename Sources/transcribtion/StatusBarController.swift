import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem(title: "Hide Panel", action: #selector(togglePanel), keyEquivalent: "h")
    private let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
    private weak var panel: NSPanel?
    private let transcription: TranscriptionController

    init(panel: NSPanel, transcription: TranscriptionController) {
        self.panel = panel
        self.transcription = transcription
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "CaptionLayer")
            image?.isTemplate = true
            button.image = image
        }

        toggleItem.target = self
        quitItem.target = self
        menu.delegate = self
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
        updateToggleTitle()
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            transcription.stopListening()
        } else {
            panel.makeKeyAndOrderFront(nil)
            transcription.resumeListening()
        }
        updateToggleTitle()
    }

    @objc private func quitApp() {
        transcription.stopListening()
        NSApplication.shared.terminate(nil)
    }

    private func updateToggleTitle() {
        guard let panel else { return }
        toggleItem.title = panel.isVisible ? "Hide Panel" : "Show Panel"
    }
}

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateToggleTitle()
    }
}
