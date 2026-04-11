import Foundation
import ObjectiveC.runtime

public enum RuntimeInspector {
    private static let singletonSelectors = [
        "sharedInstance",
        "shared",
        "sharedManager",
        "sharedApplication",
        "defaultCenter",
        "current",
    ]

    public static func resolutionOptions(forClassNamed className: String) -> RuntimeInstanceResolutionOptions {
        RuntimeInstanceResolutionOptions(
            autoResolvedInstance: resolveKnownSingleton(classNamed: className),
            manualCandidates: discoverManualCandidates(forClassNamed: className)
        )
    }

    public static func resolveKnownSingleton(classNamed className: String) -> ResolvedRuntimeInstance? {
        guard let cls = NSClassFromString(className) else { return nil }

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
                acquisitionDescription: selectorName,
                subjectKind: .instance,
                targetClass: cls,
                object: object
            )
        }

        return nil
    }

    public static func discoverManualCandidates(forClassNamed className: String) -> [RuntimeInstanceCandidate] {
        guard let cls = NSClassFromString(className),
              let metaClass = object_getClass(cls)
        else { return [] }

        var seen = Set<String>()
        var candidates: [RuntimeInstanceCandidate] = []
        var count: UInt32 = 0

        if let methods = class_copyMethodList(metaClass, &count) {
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

                candidates.append(
                    RuntimeInstanceCandidate(
                        selectorName: selectorName,
                        displayName: selectorName,
                        subtitle: "Zero-argument class getter",
                        kind: .classGetter
                    )
                )
            }
        }

        if supportsZeroArgumentInitialization(forClassNamed: className) {
            candidates.append(
                RuntimeInstanceCandidate(
                    selectorName: "init",
                    displayName: "init()",
                    subtitle: "Create a new zero-argument instance",
                    kind: .zeroArgumentInitializer
                )
            )
        }

        return candidates.sorted { lhs, rhs in
            if singletonSelectors.contains(lhs.selectorName), singletonSelectors.contains(rhs.selectorName) == false { return true }
            if singletonSelectors.contains(rhs.selectorName), singletonSelectors.contains(lhs.selectorName) == false { return false }
            if lhs.kind == .zeroArgumentInitializer, rhs.kind != .zeroArgumentInitializer { return false }
            if rhs.kind == .zeroArgumentInitializer, lhs.kind != .zeroArgumentInitializer { return true }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    public static func resolve(classNamed className: String, candidate: RuntimeInstanceCandidate) -> ResolvedRuntimeInstance? {
        switch candidate.kind {
        case .classGetter:
            resolve(classNamed: className, selectorName: candidate.selectorName)
        case .zeroArgumentInitializer:
            createZeroArgumentInstance(classNamed: className)
        }
    }

    public static func resolve(classNamed className: String, selectorName: String) -> ResolvedRuntimeInstance? {
        guard let cls = NSClassFromString(className) else { return nil }

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
            acquisitionDescription: selectorName,
            subjectKind: .instance,
            targetClass: cls,
            object: object
        )
    }

    public static func resolveClassObject(classNamed className: String) -> ResolvedRuntimeInstance? {
        guard let cls = NSClassFromString(className) else { return nil }

        return ResolvedRuntimeInstance(
            className: className,
            selectorName: className,
            acquisitionDescription: className,
            subjectKind: .classObject,
            targetClass: cls,
            object: nil
        )
    }

    public static func createZeroArgumentInstance(classNamed className: String) -> ResolvedRuntimeInstance? {
        guard let cls = NSClassFromString(className) else { return nil }

        let allocSelector = NSSelectorFromString("alloc")
        let initSelector = NSSelectorFromString("init")

        guard classDeclaresZeroArgumentInit(cls),
              let allocMethod = class_getClassMethod(cls, allocSelector),
              let initMethod = class_getInstanceMethod(cls, initSelector)
        else { return nil }

        let allocArgCount = max(Int(method_getNumberOfArguments(allocMethod)) - 2, 0)
        let initArgCount = max(Int(method_getNumberOfArguments(initMethod)) - 2, 0)
        let allocReturnType = RuntimeInvocationEngine.methodReturnType(allocMethod)
        let initReturnType = RuntimeInvocationEngine.methodReturnType(initMethod)

        guard allocArgCount == 0,
              initArgCount == 0,
              RuntimeInvocationEngine.returnKind(for: allocReturnType) == .object,
              RuntimeInvocationEngine.returnKind(for: initReturnType) == .object
        else { return nil }

        guard let allocatedObject = try? RuntimeInvocationEngine.invokeClassObjectMethod(on: cls, selector: allocSelector),
              let initializedObject = try? RuntimeInvocationEngine.invokeInstanceObjectMethod(on: allocatedObject, selector: initSelector)
        else { return nil }

        return ResolvedRuntimeInstance(
            className: className,
            selectorName: "init",
            acquisitionDescription: "alloc -> init()",
            subjectKind: .instance,
            targetClass: cls,
            object: initializedObject
        )
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

    private static func supportsZeroArgumentInitialization(forClassNamed className: String) -> Bool {
        guard let cls = NSClassFromString(className),
              classDeclaresZeroArgumentInit(cls),
              let allocMethod = class_getClassMethod(cls, NSSelectorFromString("alloc")),
              let initMethod = class_getInstanceMethod(cls, NSSelectorFromString("init"))
        else { return false }

        let allocArgCount = max(Int(method_getNumberOfArguments(allocMethod)) - 2, 0)
        let initArgCount = max(Int(method_getNumberOfArguments(initMethod)) - 2, 0)
        let allocReturnType = RuntimeInvocationEngine.methodReturnType(allocMethod)
        let initReturnType = RuntimeInvocationEngine.methodReturnType(initMethod)

        return allocArgCount == 0 &&
            initArgCount == 0 &&
            RuntimeInvocationEngine.returnKind(for: allocReturnType) == .object &&
            RuntimeInvocationEngine.returnKind(for: initReturnType) == .object
    }

    private static func classDeclaresZeroArgumentInit(_ cls: AnyClass) -> Bool {
        var count: UInt32 = 0
        guard let methods = class_copyMethodList(cls, &count) else { return false }
        defer { free(methods) }

        return (0..<Int(count)).contains { index in
            NSStringFromSelector(method_getName(methods[index])) == "init" &&
                max(Int(method_getNumberOfArguments(methods[index])) - 2, 0) == 0
        }
    }
}
