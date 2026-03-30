import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: VoiceIMEController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            let controller = VoiceIMEController()
            self.controller = controller
            controller.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            controller?.stop()
        }
    }
}
