//
//  RuntimeTypeSearchScope.swift
//  HeaderViewer
    

import Foundation


enum RuntimeTypeSearchScope: Hashable {
    case all
    case classes
    case protocols

    func runtimeObjects(classNames: [String], protocolNames: [String], matching searchString: String) -> [RuntimeObjectType] {
        var objects: [RuntimeObjectType] = []
        if includesClasses {
            objects += classNames.map { .class(named: $0) }
        }
        if includesProtocols {
            objects += protocolNames.map { .protocol(named: $0) }
        }
        if searchString.isEmpty { return objects }
        return objects.filter { $0.name.localizedCaseInsensitiveContains(searchString) }
    }

    
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
