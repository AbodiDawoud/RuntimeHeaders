//
//  ResolvedRuntimeInstance.swift
//  RuntimeHeaders
//

import Foundation

enum RuntimeInspectionSubjectKind {
    case instance
    case classObject
}

struct ResolvedRuntimeInstance {
    let className: String
    let selectorName: String
    let acquisitionDescription: String
    let subjectKind: RuntimeInspectionSubjectKind
    let targetClass: AnyClass
    let object: AnyObject?

    var displayName: String {
        switch subjectKind {
        case .instance:
            guard let object else { return className }
            return NSStringFromClass(type(of: object))
        case .classObject:
            return NSStringFromClass(targetClass)
        }
    }

    var pointerDescription: String? {
        switch subjectKind {
        case .instance:
            guard let object else { return nil }
            let pointer = Unmanaged.passUnretained(object).toOpaque()
            return String(describing: pointer)
        case .classObject:
            let pointer = unsafeBitCast(targetClass, to: UnsafeRawPointer.self)
            return String(describing: pointer)
        }
    }

    var inspectorTitle: String {
        switch subjectKind {
        case .instance:
            "Live Object"
        case .classObject:
            "Class Members"
        }
    }

    var subjectDescription: String {
        switch subjectKind {
        case .instance:
            "Instance"
        case .classObject:
            "Class"
        }
    }
}

extension ResolvedRuntimeInstance: Identifiable {
    var id: String {
        "\(className)"
    }
}
