//
//  RuntimeInstanceResolver.swift
//  RuntimeHeaders
//

import Foundation
import ObjectiveC.runtime

struct RuntimeInstanceResolutionOptions {
    let autoResolvedInstance: ResolvedRuntimeInstance?
    let manualCandidates: [String]
}

enum RuntimeInstanceResolver {
    private static let singletonSelectors = [
        "sharedInstance",
        "shared",
        "sharedManager",
        "sharedApplication",
        "defaultCenter",
        "current",
        "currentDevice",
        "standard",
        "defaultWorkspace",
        "main",
    ]

    static func resolutionOptions(type: RuntimeObjectType) -> RuntimeInstanceResolutionOptions {
        let autoResolvedInstance = resolveKnownSingleton(type: type)
        let manualCandidates = discoverManualCandidates(type: type)

        return RuntimeInstanceResolutionOptions(
            autoResolvedInstance: autoResolvedInstance,
            manualCandidates: manualCandidates
        )
    }

    static func resolveKnownSingleton(type: RuntimeObjectType) -> ResolvedRuntimeInstance? {
        guard case .class(let className) = type,
              let cls = NSClassFromString(className)
        else { return nil }

        for selectorName in singletonSelectors {
            let selector = NSSelectorFromString(selectorName)
            guard let method = class_getClassMethod(cls, selector) else { continue }

            let argumentCount = max(Int(method_getNumberOfArguments(method)) - 2, 0)
            let returnType = RuntimeInvocationEngine.methodReturnType(method)

            guard argumentCount == 0,
                  RuntimeInvocationEngine.returnKind(for: returnType) == .object
            else { continue }

            guard let object = try? RuntimeInvocationEngine.invokeClassObjectMethod(on: cls, selector: selector) else {
                continue
            }

            return ResolvedRuntimeInstance(
                className: className,
                selectorName: selectorName,
                object: object
            )
        }

        return nil
    }

    static func discoverManualCandidates(type: RuntimeObjectType) -> [String] {
        guard case .class = type,
              let metaClass = metaclass(for: type)
        else { return [] }

        var seen = Set<String>()
        var candidates: [String] = []
        var count: UInt32 = 0

        guard let methods = class_copyMethodList(metaClass, &count) else { return [] }
        defer { free(methods) }

        for index in 0..<Int(count) {
            let method = methods[index]
            let selectorName = NSStringFromSelector(method_getName(method))
            let argumentCount = max(Int(method_getNumberOfArguments(method)) - 2, 0)
            let returnType = RuntimeInvocationEngine.methodReturnType(method)

            guard argumentCount == 0 else { continue }
            guard RuntimeInvocationEngine.returnKind(for: returnType) == .object else { continue }
            guard shouldOfferManualSelector(named: selectorName) else { continue }
            guard seen.insert(selectorName).inserted else { continue }

            candidates.append(selectorName)
        }

        return candidates.sorted { lhs, rhs in
            if singletonSelectors.contains(lhs), singletonSelectors.contains(rhs) == false { return true }
            if singletonSelectors.contains(rhs), singletonSelectors.contains(lhs) == false { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    static func resolve(type: RuntimeObjectType, selectorName: String) -> ResolvedRuntimeInstance? {
        guard case .class(let className) = type,
              let cls = NSClassFromString(className)
        else { return nil }

        let selector = NSSelectorFromString(selectorName)
        guard let method = class_getClassMethod(cls, selector) else { return nil }

        let argumentCount = max(Int(method_getNumberOfArguments(method)) - 2, 0)
        let returnType = RuntimeInvocationEngine.methodReturnType(method)
        guard argumentCount == 0,
              RuntimeInvocationEngine.returnKind(for: returnType) == .object
        else { return nil }

        guard let object = try? RuntimeInvocationEngine.invokeClassObjectMethod(on: cls, selector: selector) else {
            return nil
        }

        return ResolvedRuntimeInstance(
            className: className,
            selectorName: selectorName,
            object: object
        )
    }

    private static func metaclass(for type: RuntimeObjectType) -> AnyClass? {
        guard case .class(let className) = type,
              let cls = NSClassFromString(className)
        else { return nil }

        return object_getClass(cls)
    }

    private static func shouldOfferManualSelector(named selectorName: String) -> Bool {
        let lowered = selectorName.lowercased()
        let excludedNames = [
            "alloc",
            "new",
            "copy",
            "mutablecopy",
            "class",
            "superclass",
        ]
        let excludedPrefixes = [
            ".cxx",
            "_",
            "init",
        ]

        guard excludedNames.contains(lowered) == false else { return false }
        return excludedPrefixes.allSatisfy { lowered.hasPrefix($0) == false }
    }
}
