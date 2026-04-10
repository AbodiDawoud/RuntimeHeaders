//
//  RuntimeInstanceResolver.swift
//  RuntimeHeaders
//

import RuntimeInspectorKit

enum RuntimeInstanceResolver {
    static func resolutionOptions(type: RuntimeObjectType) -> RuntimeInstanceResolutionOptions {
        guard case .class(let className) = type else {
            return RuntimeInstanceResolutionOptions(autoResolvedInstance: nil, manualCandidates: [])
        }

        return RuntimeInspector.resolutionOptions(forClassNamed: className)
    }

    static func resolve(type: RuntimeObjectType, candidate: RuntimeInstanceCandidate) -> ResolvedRuntimeInstance? {
        guard case .class(let className) = type else { return nil }
        return RuntimeInspector.resolve(classNamed: className, candidate: candidate)
    }

    static func resolve(type: RuntimeObjectType, selectorName: String) -> ResolvedRuntimeInstance? {
        guard case .class(let className) = type else { return nil }
        return RuntimeInspector.resolve(classNamed: className, selectorName: selectorName)
    }

    static func resolveClassObject(type: RuntimeObjectType) -> ResolvedRuntimeInstance? {
        guard case .class(let className) = type else { return nil }
        return RuntimeInspector.resolveClassObject(classNamed: className)
    }
}
