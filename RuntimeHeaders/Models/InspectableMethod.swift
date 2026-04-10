//
//  InspectableMethod.swift
//  RuntimeHeaders
//

import Foundation

struct InspectableMethod: Identifiable {
    let selectorName: String
    let returnTypeEncoding: String
    let argumentCount: Int
    let returnKind: InspectableMethodReturnKind
    let isSafeToInvoke: Bool
    let invocationBlockedReason: String?
    let declaringClassName: String
    let isInherited: Bool
    let isNSObjectMember: Bool
    let isAccessibilityRelated: Bool
    let isPrivateMethod: Bool
    let isClassMethod: Bool

    var id: String { selectorName }
}
