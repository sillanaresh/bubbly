import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var bubbleController: FloatingBubbleController?
    private var statusMenuController: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
}
