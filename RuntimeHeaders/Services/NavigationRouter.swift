//
//  NavigationRouter.swift
//  RuntimeHeaders
    

import SwiftUI


@MainActor
final class AppNavigation: ObservableObject {
    @Published var selectedTab: AppTab = .content
    @Published var selectedObject: RuntimeObjectType?
    @Published var sourcePath: [NamedNode] = []

    init() {
        restoreLastSourceNodeIfNeeded()
    }

    func openNode(_ node: NamedNode) {
        sourcePath.append(node)
        LastNodeTracker.namedNode = node
    }
    
    func restoreLastSourceNodeIfNeeded() {
        guard PreferenceController.shared.preferences.restoreLastFrameworkOnLaunch,
              let node = LastNodeTracker.namedNode
        else { return }

        let listNode = SystemLibraryShortcut.shortcuts
            .compactMap(\.node)
            .first { node.path.hasPrefix($0.path + "/") } ?? node.parent

        sourcePath = [listNode, node].compactMap { $0 }
    }
}

enum AppTab: Hashable {
    case content
    case history
    case settings
}
