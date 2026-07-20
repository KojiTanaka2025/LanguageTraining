import SwiftUI
import Combine

@main
struct LanguageTrainingApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var settings = AppSettings()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("LanguageTraining") {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear {
                    // ウィンドウのフレーム自動保存を設定
                    configureWindowFrameAutosave()
                }
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    settings.isSettingsPresented = true
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
    
    private func configureWindowFrameAutosave() {
        // メインウィンドウを取得してフレーム自動保存名を設定
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.title == "LanguageTraining" }) {
                window.setFrameAutosaveName("LanguageTrainingMainWindow")
            }
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // すべてのウィンドウにフレーム自動保存を設定
        for window in NSApplication.shared.windows {
            if window.title == "LanguageTraining" {
                window.setFrameAutosaveName("LanguageTrainingMainWindow")
            }
        }
    }
}
