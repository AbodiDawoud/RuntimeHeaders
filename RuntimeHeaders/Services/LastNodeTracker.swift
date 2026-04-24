//
//  LastNodeTracker.swift
//  RuntimeHeaders
    

import Foundation

/// keeps track of the last opened bundle or framework.
enum LastNodeTracker {
    private static let pathKey = "lastNamedNodePath"

    static var path: String? {
        get {
            UserDefaults.standard.string(forKey: pathKey)
        }
        set {
            
            UserDefaults.standard.set(newValue, forKey: pathKey)
        }
    }
    
    static var namedNode: NamedNode? {
        get {
            guard let path else { return nil }
            return _ContentView.dscRootNode.node(at: path)
        }
        set {
            path = newValue?.path
        }
    }
    
    static func reset() {
        self.path = nil
    }
}
