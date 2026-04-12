//
//  FeaturedFramework.swift
//  RuntimeHeaders
    

import Foundation

struct FeaturedFramework: Identifiable {
    let title: String
    let imageName: String
    let pathCandidates: String

    var id: String { title }

    func node() -> NamedNode? {
        _ContentView.dscRootNode.node(at: pathCandidates)
    }
}

struct FeaturedFrameworkNode: Identifiable {
    let framework: FeaturedFramework
    let node: NamedNode

    var id: String { framework.id }
}

extension NamedNode {
    func node(at path: String) -> NamedNode? {
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return self }

        var current: NamedNode? = self
        for component in components {
            current = current?.children.first(where: { $0.name == component })
            if current == nil { return nil }
        }

        return current
    }
}

extension FeaturedFramework {
    static let frameworks: [FeaturedFramework] = [
        .init(
            title: "UIKitCore", imageName: "UIKit",
            pathCandidates: "/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore",
        ),
        .init(
            title: "SwiftUI", imageName: "swift-icon",
            pathCandidates: "/System/Library/Frameworks/SwiftUI.framework/SwiftUI",
        ),
        
        .init(
            title: "AVFoundation", imageName: "AVFoundation",
            pathCandidates: "/System/Library/Frameworks/AVKit.framework/AVKit",
        ),
            
        .init(
            title: "MapKit", imageName: "MapKit",
            pathCandidates: "/System/Library/Frameworks/MapKit.framework/MapKit",
        ),

        .init(
            title: "MusicKit", imageName: "MusicKit",
            pathCandidates: "/System/Library/PrivateFrameworks/MusicLibrary.framework/MusicLibrary",
        ),
    ]
}

//"/System/Library/Frameworks/Foundation.framework/Foundation"
//"/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
