//
//  RuntimeTypeSearchScope.swift
//  HeaderViewer
    

import Foundation


enum RuntimeTypeSearchScope: Hashable {
    case all
    case classes
    case protocols

    
    var includesClasses: Bool {
        switch self {
        case .all: true
        case .classes: true
        case .protocols: false
        }
    }
    
    var includesProtocols: Bool {
        switch self {
        case .all: true
        case .classes: false
        case .protocols: true
        }
    }
}
