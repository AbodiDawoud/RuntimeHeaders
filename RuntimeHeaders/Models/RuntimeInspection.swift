//
//  RuntimeInspection.swift
//  RuntimeHeaders
    

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


enum RuntimeInstanceCandidateKind {
    case classGetter
    case zeroArgumentInitializer
}


struct RuntimeInstanceCandidate: Identifiable {
    let selectorName: String
    let displayName: String
    let subtitle: String
    let kind: RuntimeInstanceCandidateKind

    var id: String { kindId + ":" + selectorName }

    private var kindId: String {
        switch kind {
        case .classGetter: "getter"
        case .zeroArgumentInitializer: "initializer"
        }
    }
}


struct RuntimeInstanceResolutionOptions {
    let autoResolvedInstance: ResolvedRuntimeInstance?
    let manualCandidates: [RuntimeInstanceCandidate]
}
