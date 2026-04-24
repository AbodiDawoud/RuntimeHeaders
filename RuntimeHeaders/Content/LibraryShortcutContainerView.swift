//
//  LibraryShortcutContainerView.swift
//  RuntimeHeaders
    

import SwiftUI


/// Library Shortcut Container View
struct LSContainerView: View {
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(SystemLibraryShortcut.shortcuts) { shortcut in
                        NavigationLink(value: shortcut.node) {
                            shortcutRowView(shortcut)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.init())
            .listRowSeparator(.hidden)
            
        } header: {
            Text("Library Shortcuts")
        }
    }

    func shortcutRowView(_ item: SystemLibraryShortcut) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(.frameworkIcon)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.blue.gradient)
                .scaledToFit()
                .frame(width: 27, height: 27)
                .shadow(radius: 6, y: 2.8)
            
            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 15)
        .background(
            Color(
                scheme == .dark ? UIColor.systemGray6 : UIColor.systemBackground
            ),
            in: .capsule
        )
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }
}
