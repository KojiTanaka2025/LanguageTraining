import SwiftUI
import Combine

@main
struct EnglishCardApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup("EnglishCard") {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("設定…") {
                    settings.isSettingsPresented = true
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}

