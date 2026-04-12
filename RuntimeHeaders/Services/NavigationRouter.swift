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

    func selectObject(_ object: RuntimeObjectType?, parentPath: String? = nil) {
        selectedObject = object
    }

    func openNode(_ node: NamedNode) {
        sourcePath.append(node)
        LastNodeTracker.namedNode = node
    }
    
    func restoreLastSourceNodeIfNeeded() {
        guard PreferenceController.shared.preferences.restoreLastFrameworkOnLaunch,
              let node = LastNodeTracker.namedNode
        else { return }

        sourcePath = [node]
    }
}

enum AppTab: Hashable {
    case content
    case history
    case settings
}
