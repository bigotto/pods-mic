import AppKit
import os

let log = Logger(subsystem: "com.bigotto.PodsMic", category: "app")

@main
enum PodsMicApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
