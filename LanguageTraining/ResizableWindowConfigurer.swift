import SwiftUI

#if os(macOS)
import AppKit

/// Forces the hosting NSWindow to be user-resizable (SwiftUI Settings scenes often are not).
struct ResizableWindowConfigurer: NSViewRepresentable {
    var minWidth: CGFloat = 480
    var minHeight: CGFloat = 360

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        DispatchQueue.main.async {
            Self.configure(window: view.window, minWidth: minWidth, minHeight: minHeight)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.configure(window: nsView.window, minWidth: minWidth, minHeight: minHeight)
        }
    }

    private static func configure(window: NSWindow?, minWidth: CGFloat, minHeight: CGFloat) {
        guard let window else { return }
        if !window.styleMask.contains(.resizable) {
            window.styleMask.insert(.resizable)
        }
        let minSize = NSSize(width: minWidth, height: minHeight)
        if window.minSize != minSize {
            window.minSize = minSize
        }
        if window.contentMinSize != minSize {
            window.contentMinSize = minSize
        }
    }
}

struct SettingsWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
#endif
