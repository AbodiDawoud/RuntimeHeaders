//
//  HeaderViewerApp.swift
//  HeaderViewer


import SwiftUI

@main
struct HeaderViewerApp: App {
    @ObservedObject var hm = HistoryManager()
    
    var body: some Scene {
        WindowGroup {
            _HomeView().environmentObject(hm)
        }
    }
}


private struct _HomeView: View {
    @ObservedObject var settingsManager = PreferenceController.shared

    var body: some View {
        TabView {
            ContentView().tabItem {
                Label("Content", systemImage: "externaldrive")
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
