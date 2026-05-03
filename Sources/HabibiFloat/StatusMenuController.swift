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
            button.image = Self.makeStatusBubbleIcon()
            button.imagePosition = .imageOnly
        }

        controller.onStateChanged = { [weak self] in
            self?.refreshMenu()
        }
        statusItem.menu = makeMenu()
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "Bubbly")

        let titleItem = NSMenuItem(title: "Bubbly", action: nil, keyEquivalent: "")
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
        menu.addItem(themeMenu())
        menu.addItem(moodMenu())
        menu.addItem(characterMenu())
        menu.addItem(featureModeMenu())
        menu.addItem(smartPositioningItem())
        menu.addItem(soundMenu())
        menu.addItem(volumeMenu())
        menu.addItem(.separator())
        menu.addItem(item("About Bubbly", action: #selector(showAbout)))
        menu.addItem(item("Quit Bubbly", action: #selector(quitApp), key: "q"))

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

    @objc private func chooseTheme(_ sender: NSMenuItem) {
        guard let theme = sender.representedObject as? BubbleTheme else {
            return
        }

        controller?.setTheme(theme)
        refreshMenu()
    }

    @objc private func chooseMood(_ sender: NSMenuItem) {
        guard let mood = sender.representedObject as? BubbleMood else {
            return
        }

        controller?.setMood(mood)
        refreshMenu()
    }

    @objc private func chooseCharacter(_ sender: NSMenuItem) {
        guard let character = sender.representedObject as? BubbleCharacter else {
            return
        }

        controller?.setCharacter(character)
        refreshMenu()
    }

    @objc private func chooseFeatureMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? BubbleFeatureMode else {
            return
        }

        controller?.setFeatureMode(mode)
        refreshMenu()
    }

    @objc private func toggleSmartPositioning() {
        controller?.setSmartPositioningEnabled(!(controller?.smartPositioningEnabled ?? true))
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

    private func themeMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Theme")
        let selectedID = controller?.themeID ?? BubbleTheme.ocean.rawValue

        for theme in BubbleTheme.allCases {
            let item = NSMenuItem(title: theme.title, action: #selector(chooseTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme
            item.state = theme.rawValue == selectedID ? .on : .off
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func moodMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Mood", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Mood")
        let selectedID = controller?.moodID ?? BubbleMood.happy.rawValue

        for mood in BubbleMood.allCases {
            let item = NSMenuItem(title: mood.title, action: #selector(chooseMood(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mood
            item.state = mood.rawValue == selectedID ? .on : .off
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func characterMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Character", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Character")
        let selectedID = controller?.characterID ?? BubbleCharacter.bubble.rawValue

        for character in BubbleCharacter.allCases {
            let item = NSMenuItem(title: character.title, action: #selector(chooseCharacter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = character
            item.state = character.rawValue == selectedID ? .on : .off
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func featureModeMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Feature Mode", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Feature Mode")
        let selectedID = controller?.featureModeID ?? BubbleFeatureMode.chat.rawValue

        for mode in BubbleFeatureMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(chooseFeatureMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = mode.rawValue == selectedID ? .on : .off
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func smartPositioningItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Smart Positioning", action: #selector(toggleSmartPositioning), keyEquivalent: "")
        item.target = self
        item.state = controller?.smartPositioningEnabled == true ? .on : .off
        return item
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

    private static func makeStatusBubbleIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        bounds.fill()

        let bodyRect = bounds.insetBy(dx: 2, dy: 2)
        NSColor.black.setStroke()
        let outline = NSBezierPath(ovalIn: bodyRect)
        outline.lineWidth = 1.6
        outline.stroke()

        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 6, y: 9, width: 2.4, height: 2.8)).fill()
        NSBezierPath(ovalIn: NSRect(x: 10.2, y: 9, width: 2.4, height: 2.8)).fill()

        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: 7.2, y: 6.8))
        smile.curve(
            to: NSPoint(x: 11.2, y: 6.8),
            controlPoint1: NSPoint(x: 8.2, y: 5.9),
            controlPoint2: NSPoint(x: 10.2, y: 5.9)
        )
        NSColor.black.setStroke()
        smile.lineWidth = 1.2
        smile.lineCapStyle = .round
        smile.stroke()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "Bubbly"
        return image
    }
}
