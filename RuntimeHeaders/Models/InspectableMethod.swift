//
//  InspectableMethod.swift
//  RuntimeHeaders
//

import Foundation

enum InspectableMethodReturnKind: String {
    case void
    case object
    case bool
    case integer
    case unsignedInteger
    case floatingPoint
    case unsupported
}

struct InspectableMethod: Identifiable {
    let selectorName: String
    let returnTypeEncoding: String
    let argumentCount: Int
    let returnKind: InspectableMethodReturnKind
    let isSafeToInvoke: Bool
    let declaringClassName: String
    let isInherited: Bool
    let isNSObjectMember: Bool
    let isAccessibilityRelated: Bool

    var id: String { selectorName }
}
