import SwiftUI
import Combine
import UniformTypeIdentifiers

private enum AppTab: Hashable {
    case explain
    case library
    case study
    case settings
}

struct ContentView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedTab: AppTab = .explain

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Explain", systemImage: "sparkles", value: .explain) {
                ExplainView()
            }

            Tab("Library", systemImage: "books.vertical", value: .library) {
                LibraryView()
            }

            Tab("Study", systemImage: "rectangle.on.rectangle.angled", value: .study) {
                StudyView()
            }

            #if os(iOS)
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                }
            }
            #endif
        }
        .onAppear {
            store.loadIfNeeded()
        }
        .safeAreaInset(edge: .bottom) {
            if let message = store.loadErrorMessage {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Library could not be loaded")
                            .font(.headline)
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Saving is disabled so existing cards are not overwritten.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Retry") {
                        store.reloadData()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
                .background(.bar)
            }
        }
    }
}
