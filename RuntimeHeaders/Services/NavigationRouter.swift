//
//  NavigationRouter.swift
//  RuntimeHeaders
    

import SwiftUI


@MainActor
final class AppNavigation: ObservableObject {
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
