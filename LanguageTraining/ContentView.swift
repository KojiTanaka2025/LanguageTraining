import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            ExplainView()
                .tabItem { Label("Explain", systemImage: "sparkles") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "list.bullet.rectangle") }
        }
        .sheet(isPresented: $settings.isSettingsPresented, onDismiss: {
            // 設定画面を閉じたときにデータを再読み込み（インポート後の反映）
            store.reloadData()
        }) {
            SettingsView()
                .environmentObject(settings)
        }
        .onAppear {
            store.loadIfNeeded()
        }
    }
}
