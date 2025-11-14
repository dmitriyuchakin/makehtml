import SwiftUI
import AppKit

// App delegate to handle file opening
class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle files opened via "Open With" or drag-to-dock
        for url in urls where url.pathExtension.lowercased() == "docx" {
            NotificationCenter.default.post(name: .openDocxFile, object: url)
        }
    }
}

@main
struct makeHTMLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 720)
    }
}

// Notification for opening DOCX files
extension Notification.Name {
    static let openDocxFile = Notification.Name("openDocxFile")
}
