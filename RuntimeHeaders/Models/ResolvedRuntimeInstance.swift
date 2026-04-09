//
//  ResolvedRuntimeInstance.swift
//  RuntimeHeaders
//

import Foundation

struct ResolvedRuntimeInstance {
    let className: String
    let selectorName: String
    let object: AnyObject

    var displayName: String {
        NSStringFromClass(type(of: object))
    }

    var pointerDescription: String {
        let pointer = Unmanaged.passUnretained(object).toOpaque()
        return String(describing: pointer)
    }
}

extension ResolvedRuntimeInstance: Identifiable {
    var id: String {
        className + ":" + selectorName + ":" + pointerDescription
    }
}
