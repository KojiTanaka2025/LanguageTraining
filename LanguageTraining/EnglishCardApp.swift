import SwiftUI
import Combine

#if os(macOS)
import AppKit

@main
struct LanguageTrainingApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var settings = AppSettings()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("LanguageTraining", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
                .frame(minWidth: 980, minHeight: 640)
                .background(WindowFramePersistence())
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(settings)
                .frame(minWidth: 480, minHeight: 360)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .defaultSize(width: 580, height: 720)
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        LayoutPersistence.saveNow()
    }
}
#else
@main
struct LanguageTrainingApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}
#endif
