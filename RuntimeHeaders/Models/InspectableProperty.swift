//
//  InspectableProperty.swift
//  RuntimeHeaders
//

import Foundation

struct InspectableProperty: Identifiable {
    let name: String
    let getterName: String
    let attributes: String
    let valueDescription: String
    let errorMessage: String?
    let declaringClassName: String
    let isInherited: Bool
    let isNSObjectMember: Bool
    let isAccessibilityRelated: Bool

    var id: String { name }
    var isReadable: Bool { errorMessage == nil }
}
