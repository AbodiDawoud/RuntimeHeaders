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
        var swiftClasses: [RuntimeObjectType] = []
        if includesClasses {
            for name in classNames {
                let object = RuntimeObjectType.class(named: name)
                if object.isSwiftClass {
                    swiftClasses.append(object)
                } else {
                    objects.append(object)
                }
            }
        }
        if includesProtocols {
            objects += protocolNames.map { .protocol(named: $0) }
        }
        objects += swiftClasses
        if searchString.isEmpty { return objects }
        return objects.filter {
            $0.name.localizedCaseInsensitiveContains(searchString) || $0.displayName.localizedCaseInsensitiveContains(searchString)
        }
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
