import SwiftUI
import Combine

/// サイドバーを使った3ペインレイアウトの拡張版
/// より大きな画面で使いやすいデザイン
struct AlternativeContentView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings
    
    @State private var selectedTab: SidebarItem = .explain
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case explain = "Explain"
        case library = "Library"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .explain: return "sparkles"
            case .library: return "list.bullet.rectangle"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // サイドバー
            List(SidebarItem.allCases, selection: $selectedTab) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text("LanguageTraining")
                        .font(.headline)
                }
            }
        } detail: {
            // メインコンテンツ
            Group {
                switch selectedTab {
                case .explain:
                    ExplainView()
                case .library:
                    LibraryView()
                }
            }
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
