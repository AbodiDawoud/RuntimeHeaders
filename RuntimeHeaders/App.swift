//
//  HeaderViewerApp.swift
//  HeaderViewer


import SwiftUI
import Toasts

@main
struct HeaderViewerApp: App {
    @State var hm = HistoryManager()
    
    var body: some Scene {
        WindowGroup {
            _HomeView()
                .environment(hm)
                .installToast(position: .bottom)
        }
    }
}


private struct _HomeView: View {
    @ObservedObject var settingsManager = PreferenceController.shared
    @StateObject private var navigation = AppNavigation()
    
    
    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            ContentView().tabItem {
                Label("Content", systemImage: "externaldrive")
            }
            .tag(AppTab.content)
            
            HistoryView().tabItem {
                Label("History", image: "document.fill.badge.clock")
            }
            .tag(AppTab.history)
            
            SettingsView().tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(AppTab.settings)
        }
        .environmentObject(navigation)
        .preferredColorScheme(settingsManager.preferences.colorScheme())
        .onAppear(perform: setTabBarAppearance)
        .onChange(of: settingsManager.preferences.preferredColorScheme) { _, newValue in
            let newScheme: ColorScheme = newValue == "light" ? .light : .dark
            CodePreferences.shared.toggleThemeBasedOnColorScheme(newScheme)
        }
    }
    
    func setTabBarAppearance() {
        let appearance = UITabBarAppearance()
        setTabBarColors(appearance.stackedLayoutAppearance)
        setTabBarColors(appearance.compactInlineLayoutAppearance)
        setTabBarColors(appearance.inlineLayoutAppearance)
        
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        UITabBar.appearance().standardAppearance.stackedItemPositioning = .fill
    }
    
    func setTabBarColors(_ item: UITabBarItemAppearance) {
        item.normal.iconColor = .gray
        item.selected.iconColor = UIColor(Color.primary)
        item.normal.badgeBackgroundColor = .systemBlue
    }
}
