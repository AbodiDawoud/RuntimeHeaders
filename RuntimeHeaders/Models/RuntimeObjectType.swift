//
//  RuntimeObjectType.swift
//  HeaderViewer

import SwiftUI


enum RuntimeObjectType {
    case `class`(named: String)
    case `protocol`(named: String)

    
    var name: String {
        switch self {
        case .class(let name): return name
        case .protocol(let name): return name
        }
    }
    
    var systemImageName: String {
        switch self {
        case .class: return "c.square.fill"
        case .protocol: return "p.square.fill"
        }
    }
    
    
    var iconColor: Color {
        switch self {
        case .class: return .green
        case .protocol: return .pink
        }
    }
}

extension RuntimeObjectType: Codable, Hashable, Identifiable {
    var id: Self { self }
}
