import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var bubbleController: FloatingBubbleController?
    private var statusMenuController: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        let preferences = UserDefaultsPreferencesStore()
        let bubbleController = FloatingBubbleController(preferences: preferences)
        let statusMenuController = StatusMenuController(controller: bubbleController)

        bubbleController.contextMenuProvider = { [weak statusMenuController] in
            statusMenuController?.makeMenu() ?? NSMenu()
        }

        self.bubbleController = bubbleController
        self.statusMenuController = statusMenuController

        bubbleController.restoreInitialState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        bubbleController?.persistCurrentState()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "Habibi Float")

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Habibi Float")
        appMenu.addItem(NSMenuItem(title: "Quit Habibi Float", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }
}
