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
        .safeAreaInset(edge: .bottom) {
            if let message = store.loadErrorMessage {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Library could not be loaded")
                            .font(.headline)
                        Text(message)
                            .font(.callout)
                            .textSelection(.enabled)
                        Text("Saving is disabled so your existing cards.xml is not overwritten.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Retry") {
                        store.reloadData()
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
    }
}
