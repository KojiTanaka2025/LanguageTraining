import SwiftUI
import Combine

#if os(macOS)
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
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
