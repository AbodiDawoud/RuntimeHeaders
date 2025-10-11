//
//  HeaderViewerApp.swift
//  HeaderViewer


import SwiftUI

@main
struct HeaderViewerApp: App {
    var body: some Scene {
        WindowGroup {
            _HomeView()
                .environmentObject(HistoryManager())
        }
    }
}


private struct _HomeView: View {
    @ObservedObject var settingsManager = SettingsManager.shared

    var body: some View {
        TabView {
            ContentView().tabItem {
                Label("Content", systemImage: "list.bullet.rectangle.fill")
            }
            
            HistoryView().tabItem {
                Label("History", image: "document.fill.badge.clock")
            }
            
            SettingsView().tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .preferredColorScheme(settingsManager.preferences.colorScheme())
        .onAppear(perform: setTabBarAppearance)
        .onChange(
            of: settingsManager.preferences.preferredColorScheme,
            CodePreferences.shared.toggleThemeBasedOnColorScheme
        )
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
