//
//  RuntimeObjectType.swift
//  RuntimeHeaders
    

import SwiftUI

enum RuntimeObjectType {
    case `class`(named: String)
    case `protocol`(named: String)

    var isClass: Bool {
        if case .class = self { return true }
        return false
    }

    var name: String {
        switch self {
        case .class(let name): return name
        case .protocol(let name): return name
        }
    }

    var displayName: String {
        guard isClass, let cls = NSClassFromString(name) else { return name }
        return String(reflecting: cls)
    }

    var isSwiftClass: Bool {
        // Reflection preserves Swift's qualified name, including @objc aliases.
        isClass && (name.hasPrefix("_Tt") || displayName.contains("."))
    }

    var systemImageName: String {
        switch self {
        case .class: return "c.square.fill"
        case .protocol: return "p.square.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .class: return isSwiftClass ? .orange : .green
        case .protocol: return .pink
        }
    }
}

extension RuntimeObjectType: Codable, Hashable, Identifiable {
    var id: Self { self }
}
