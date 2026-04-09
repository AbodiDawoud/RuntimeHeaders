//
//  HistoryView.swift
//  HeaderViewer

import SwiftUI

 
struct HistoryView: View {
    @EnvironmentObject private var manager: HistoryManager
    @ObservedObject private var settingsManager = PreferenceController.shared
    
    
    var body: some View {
        NavigationStack {
            List {
                if manager.isHistoryEmpty {
                    Section { historyStatusView }
                }
                
                if manager.historyCount > 3 {
                    LatestHistoryContainerView()
                }
                
                
                ForEach(_h_items) { obj in
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
    
    // history items
    var _h_items: [RuntimeObjectType] {
        if manager.historyCount > 3 {
            return Array(manager.historyItems.dropFirst(3))
        }
        return manager.historyItems
    }
}


struct LatestHistoryContainerView: View {
    @EnvironmentObject private var manager: HistoryManager
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(Array(manager.historyItems.prefix(3))) { obj in
                        NavigationLink {
                            RuntimeObjectDetail(type: obj)
                        } label: {
                            rowView(obj)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.init())
            .listRowSeparator(.hidden)
        } header: {
            Text("Latest Items")
        } footer: {
            Text("Quickly access your most recent viewed objects..")
        }
    }
    
    func rowView(_ object: RuntimeObjectType) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(.fileStackIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .shadow(radius: 6, y: 2.8)
            
            Text(object.name)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background(
            Color(
                scheme == .dark ? UIColor.systemGray6 : UIColor.systemBackground
            ),
            in: .rect(cornerRadius: 17)
        )
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }
}
