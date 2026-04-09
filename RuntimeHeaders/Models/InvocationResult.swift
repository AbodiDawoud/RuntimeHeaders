//
//  InvocationResult.swift
//  RuntimeHeaders
//

import Foundation

struct InvocationResult: Identifiable {
    let selectorName: String
    let valueDescription: String
    let errorMessage: String?

    var id: String { selectorName + valueDescription }
    var isSuccess: Bool { errorMessage == nil }
}
