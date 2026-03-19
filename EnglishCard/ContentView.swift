import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            ExplainView()
                .tabItem { Label("英語解説", systemImage: "sparkles") }

            LibraryView()
                .tabItem { Label("一覧", systemImage: "list.bullet.rectangle") }
        }
        .sheet(isPresented: $settings.isSettingsPresented) {
            SettingsView()
                .environmentObject(settings)
        }
        .onAppear {
            store.loadIfNeeded()
        }
    }
}

