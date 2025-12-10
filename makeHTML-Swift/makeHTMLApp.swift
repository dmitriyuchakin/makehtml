import SwiftUI
import AppKit

// App delegate to handle file opening and custom About panel
class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle files opened via "Open With" or drag-to-dock
        for url in urls where url.pathExtension.lowercased() == "docx" {
            NotificationCenter.default.post(name: .openDocxFile, object: url)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Override the About menu item
        if let menu = NSApp.mainMenu?.items.first?.submenu {
            for item in menu.items {
                if item.title == "About makeHTML" {
                    item.target = self
                    item.action = #selector(showCustomAbout)
                }
            }
        }
    }

    @objc func showCustomAbout() {
        let alert = NSAlert()
        alert.messageText = "makeHTML"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        // Create attributed string with clickable email link
        let message = "Version 0.5 (Build 1111)\n\nTo report bugs and request features, send email to \n"
        let email = "dmitriy@uchakin.com"

        let attributedString = NSMutableAttributedString(string: message + email)

        // Create paragraph style with custom line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 2  // Adjust this value to control line spacing (0-10 typical range)
        paragraphStyle.paragraphSpacing = 8  // Space between paragraphs

        // Apply paragraph style to entire string
        let fullRange = NSRange(location: 0, length: attributedString.length)
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

        // Set text color for the message (adapts to dark/light mode)
        let messageRange = NSRange(location: 0, length: message.count)
        attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: messageRange)

        // Add link attribute to the email part
        let emailRange = NSRange(location: message.count, length: email.count)
        attributedString.addAttribute(.link, value: "mailto:dmitriy@uchakin.com", range: emailRange)
        attributedString.addAttribute(.foregroundColor, value: NSColor.linkColor, range: emailRange)

        // Create text view to display the message with clickable link
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        textView.textStorage?.setAttributedString(attributedString)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false

        alert.accessoryView = textView
        alert.informativeText = ""

        alert.runModal()
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
