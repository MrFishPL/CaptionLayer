import AppKit

@available(macOS 14.4, *)
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem(title: "Hide Panel", action: #selector(togglePanel), keyEquivalent: "h")
    private let removeTokenItem = NSMenuItem(title: "Remove Token", action: #selector(removeToken), keyEquivalent: "")
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
        removeTokenItem.target = self
        quitItem.target = self
        menu.delegate = self
        menu.autoenablesItems = false
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(removeTokenItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
        updateToggleTitle()
        updateTokenItems()
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

    private func updateTokenItems() {
        let hasToken = EnvLoader.loadApiKey() != nil
        removeTokenItem.isEnabled = hasToken
    }

    @objc private func removeToken() {
        EnvLoader.removeApiKey()
        updateTokenItems()
        alertBeforeQuit()
    }

    private func alertBeforeQuit() {
        let alert = NSAlert()
        alert.messageText = "Token Removed"
        alert.informativeText = "Capture Layer will now quit. Please reopen it to continue."
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApplication.shared.terminate(nil)
    }
}

@available(macOS 14.4, *)
extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateToggleTitle()
        updateTokenItems()
    }
}
