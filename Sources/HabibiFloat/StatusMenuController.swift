import AppKit

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private weak var controller: FloatingBubbleController?
    private let aboutWindowController = AboutWindowController()

    init(controller: FloatingBubbleController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Habibi Float")
            button.imagePosition = .imageOnly
        }

        controller.onStateChanged = { [weak self] in
            self?.refreshMenu()
        }
        statusItem.menu = makeMenu()
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "Habibi Float")

        let titleItem = NSMenuItem(title: "Habibi Float", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        if controller?.isVisible == true {
            menu.addItem(item("Hide Bubble", action: #selector(hideBubble)))
        } else {
            menu.addItem(item("Show Bubble", action: #selector(showBubble)))
        }

        let pauseTitle = controller?.isPaused == true ? "Resume" : "Pause"
        menu.addItem(item(pauseTitle, action: #selector(togglePause)))
        menu.addItem(item("Reset Position", action: #selector(resetPosition)))
        menu.addItem(soundMenu())
        menu.addItem(volumeMenu())
        menu.addItem(.separator())
        menu.addItem(item("About Habibi Float", action: #selector(showAbout)))
        menu.addItem(item("Quit Habibi Float", action: #selector(quitApp), key: "q"))

        return menu
    }

    @objc private func showBubble() {
        controller?.showBubble()
        refreshMenu()
    }

    @objc private func hideBubble() {
        controller?.hideBubble()
        refreshMenu()
    }

    @objc private func togglePause() {
        controller?.togglePause()
        refreshMenu()
    }

    @objc private func resetPosition() {
        controller?.resetPosition()
        refreshMenu()
    }

    @objc private func chooseSound(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? BubbleSoundPreset else {
            return
        }

        controller?.setClickSound(preset)
        refreshMenu()
    }

    @objc private func chooseVolume(_ sender: NSMenuItem) {
        guard let volume = sender.representedObject as? BubbleSoundVolume else {
            return
        }

        controller?.setSoundVolume(volume)
        refreshMenu()
    }

    @objc private func showAbout() {
        aboutWindowController.show()
    }

    @objc private func quitApp() {
        controller?.persistCurrentState()
        NSApp.terminate(nil)
    }

    private func refreshMenu() {
        statusItem.menu = makeMenu()
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func soundMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Click Sound", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Click Sound")
        let selectedID = controller?.clickSoundID ?? BubbleSoundPreset.waterDrop.rawValue

        for preset in BubbleSoundPreset.allCases {
            let item = NSMenuItem(title: preset.title, action: #selector(chooseSound(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            item.state = preset.rawValue == selectedID ? .on : .off
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func volumeMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Sound Volume", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Sound Volume")
        let selectedID = controller?.soundVolumeID ?? BubbleSoundVolume.normal.rawValue

        for volume in BubbleSoundVolume.allCases {
            let item = NSMenuItem(title: volume.title, action: #selector(chooseVolume(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = volume
            item.state = volume.rawValue == selectedID ? .on : .off
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }
}
