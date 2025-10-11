//
//  HistoryView.swift
//  HeaderViewer

import SwiftUI

 
struct HistoryView: View {
    @EnvironmentObject private var manager: HistoryManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    
    var body: some View {
        NavigationStack {
            List {
                if manager.isHistoryEmpty {
                    Section { historyStatusView }
                }
                
                ForEach(manager.historyItems) { obj in
                    NavigationLink {
                        RuntimeObjectDetail(type: obj)
                    } label: {
                        RuntimeObjectRow(type: obj)
                    }
                }
                .onDelete(perform: manager.removeObject)
            }
            .onAppear(perform: manager.refreshHistory)
            .inlinedNavigationTitle("History")
            .toolbar {
                if !manager.isHistoryEmpty {
                    ClearButton(action: manager.clearHistory)
                }
            }
            .if(!manager.isHistoryEmpty) {
                $0.refreshable {
                    manager.refreshHistory()
                }
            }
        }
        .if(settingsManager.preferences.historyBadgeEnabled) {
            $0.badge(manager.historyCount)
        }
        .animation(.default, value: manager.historyItems) // Animate "onDelete" action
    }
    
    
    @ViewBuilder
    private var historyStatusView: some View {
        if settingsManager.preferences.historyEnabled {
            Label("No History Yet", systemImage: "clock.arrow.circlepath")
                .labelStyle(EmptyStatusLabelStyle(.flora, info: "Explore new objects to see them here."))
        } else {
            Label("History Disabled", systemImage: "exclamationmark.lock.fill")
                .labelStyle(
                    EmptyStatusLabelStyle(
                        .orange,
                        secondary: .white,
                        info: "You can enable it from settings."
                    )
                )
        }
    }
}
