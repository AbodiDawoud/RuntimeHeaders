//
//  NamedNode.swift
//  HeaderViewer


import Foundation

final class NamedNode {
    let name: String
    weak var parent: NamedNode?
    private(set) var children: [NamedNode] = []
    
    
    init(_ name: String, parent: NamedNode? = nil) {
        self.name = name
        self.parent = parent
    }
    
    var isLeaf: Bool { children.isEmpty }
    
    var path: String {
        guard let parent else { return name }
        let directory = parent.path
        return directory + "/" + name
    }
    
    func child(named name: String) -> NamedNode {
        if let existing = children.first(where: { $0.name == name }) {
            return existing
        }
        
        let child = NamedNode(name, parent: self)
        children.append(child)
        
        return child
    }
}

extension NamedNode: Hashable {
    static func == (lhs: NamedNode, rhs: NamedNode) -> Bool {
        lhs.name == rhs.name && lhs.parent === rhs.parent
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(parent)
    }
}
