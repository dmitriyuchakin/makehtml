import SwiftUI

@main
struct makeHTMLApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 720)
    }
}
