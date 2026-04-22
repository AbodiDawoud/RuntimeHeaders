//
//  SystemLibraryShortcut.swift
//  RuntimeHeaders
    

import Foundation

struct SystemLibraryShortcut: Identifiable {
    let title: String
    let path: String
    
    var id: String { path }
    
    var node: NamedNode? {
        _ContentView.dscRootNode.node(at: self.path)
    }
    
    static let shortcuts: [SystemLibraryShortcut] = [
        .init(
            title: "Public Frameworks",
            path: "/System/Library/Frameworks",
        ),
        
        .init(
            title: "Private Frameworks",
            path: "/System/Library/PrivateFrameworks",
        )
    ]
}
