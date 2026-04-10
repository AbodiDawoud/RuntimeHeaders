//
//  RuntimeObjectInspectorViewModel.swift
//  RuntimeHeaders
//

import Foundation
import ObjectiveC.runtime

@MainActor
final class RuntimeObjectInspectorViewModel: ObservableObject {
    let resolvedInstance: ResolvedRuntimeInstance

    @Published private(set) var properties: [InspectableProperty] = []
    @Published private(set) var methods: [InspectableMethod] = []
    @Published private(set) var lastInvocation: InvocationResult?

    init(resolvedInstance: ResolvedRuntimeInstance) {
        self.resolvedInstance = resolvedInstance
        refresh()
    }

    var resolvedClassName: String {
        resolvedInstance.displayName
    }

    var isInspectingClass: Bool {
        resolvedInstance.subjectKind == .classObject
    }

    func refresh() {
        let collectedProperties = collectProperties()
        let propertyNames = Set(collectedProperties.filter { $0.isDirectIvar == false }.map(\.getterName))
        properties = collectedProperties
        methods = collectMethods(excluding: propertyNames)
    }

    func invoke(_ method: InspectableMethod) {
        do {
            let selector = NSSelectorFromString(method.selectorName)
            let value: String
            switch resolvedInstance.subjectKind {
            case .instance:
                guard let object = resolvedInstance.object else {
                    throw RuntimeInvocationError.nilObjectReturn(method.selectorName)
                }
                value = try RuntimeInvocationEngine.invokeInstanceMethod(
                    on: object,
                    selector: selector,
                    returnTypeEncoding: method.returnTypeEncoding
                )
            case .classObject:
                value = try RuntimeInvocationEngine.invokeClassMethod(
                    on: resolvedInstance.targetClass,
                    selector: selector,
                    returnTypeEncoding: method.returnTypeEncoding
                )
            }
            lastInvocation = InvocationResult(
                selectorName: method.selectorName,
                valueDescription: value,
                errorMessage: nil
            )
        } catch {
            lastInvocation = InvocationResult(
                selectorName: method.selectorName,
                valueDescription: "",
                errorMessage: error.localizedDescription
            )
        }
    }

    private func collectProperties() -> [InspectableProperty] {
        var results: [InspectableProperty] = []
        var seen = Set<String>()
        var currentClass: AnyClass? = propertyTraversalRootClass

        while let cls = currentClass {
            let declaringClassName = displayClassName(for: cls)
            var count: UInt32 = 0
            if let properties = class_copyPropertyList(cls, &count) {
                defer { free(properties) }

                for index in 0..<Int(count) {
                    let property = properties[index]
                    let name = String(cString: property_getName(property))
                    guard seen.insert(name).inserted else { continue }

                    let getterName: String
                    if let getter = property_copyAttributeValue(property, "G") {
                        getterName = String(cString: getter)
                        free(getter)
                    } else {
                        getterName = name
                    }

                    let attributes = property_getAttributes(property).map { String(cString: $0) } ?? ""
                    let getterSelector = NSSelectorFromString(getterName)

                    guard let method = getterMethod(on: cls, selector: getterSelector) else {
                        results.append(
                            InspectableProperty(
                                name: name,
                                getterName: getterName,
                                attributes: attributes,
                                valueDescription: "",
                                errorMessage: "Getter unavailable",
                                declaringClassName: declaringClassName,
                                isInherited: isInheritedMember(declaringClassName: declaringClassName),
                                isNSObjectMember: isNSObjectMember(declaringClassName),
                                isAccessibilityRelated: isAccessibilityRelated(name: name, alternateName: getterName),
                                isClassMember: isInspectingClass,
                                isDirectIvar: false
                            )
                        )
                        continue
                    }

                    let argumentCount = max(Int(method_getNumberOfArguments(method)) - 2, 0)
                    let returnType = RuntimeInvocationEngine.methodReturnType(method)

                    guard argumentCount == 0,
                          RuntimeInvocationEngine.returnKind(for: returnType) != .unsupported
                    else {
                        results.append(
                            InspectableProperty(
                                name: name,
                                getterName: getterName,
                                attributes: attributes,
                                valueDescription: "",
                                errorMessage: "Unsupported getter signature",
                                declaringClassName: declaringClassName,
                                isInherited: isInheritedMember(declaringClassName: declaringClassName),
                                isNSObjectMember: isNSObjectMember(declaringClassName),
                                isAccessibilityRelated: isAccessibilityRelated(name: name, alternateName: getterName),
                                isClassMember: isInspectingClass,
                                isDirectIvar: false
                            )
                        )
                        continue
                    }

                    do {
                        let value = try invoke(selector: getterSelector, returnTypeEncoding: returnType)
                        results.append(
                            InspectableProperty(
                                name: name,
                                getterName: getterName,
                                attributes: attributes,
                                valueDescription: value,
                                errorMessage: nil,
                                declaringClassName: declaringClassName,
                                isInherited: isInheritedMember(declaringClassName: declaringClassName),
                                isNSObjectMember: isNSObjectMember(declaringClassName),
                                isAccessibilityRelated: isAccessibilityRelated(name: name, alternateName: getterName),
                                isClassMember: isInspectingClass,
                                isDirectIvar: false
                            )
                        )
                    } catch {
                        results.append(
                            InspectableProperty(
                                name: name,
                                getterName: getterName,
                                attributes: attributes,
                                valueDescription: "",
                                errorMessage: error.localizedDescription,
                                declaringClassName: declaringClassName,
                                isInherited: isInheritedMember(declaringClassName: declaringClassName),
                                isNSObjectMember: isNSObjectMember(declaringClassName),
                                isAccessibilityRelated: isAccessibilityRelated(name: name, alternateName: getterName),
                                isClassMember: isInspectingClass,
                                isDirectIvar: false
                            )
                        )
                    }
                }
            }

            if isInspectingClass == false, let object = resolvedInstance.object {
                var ivarCount: UInt32 = 0
                if let ivars = class_copyIvarList(cls, &ivarCount) {
                    defer { free(ivars) }

                    for index in 0..<Int(ivarCount) {
                        let ivar = ivars[index]
                        guard let ivarName = ivar_getName(ivar) else { continue }
                        let name = String(cString: ivarName)
                        guard seen.insert(name).inserted else { continue }

                        let typeEncoding = ivar_getTypeEncoding(ivar).map { String(cString: $0) } ?? ""
                        let valueResult = describeIvarValue(object: object, ivar: ivar, typeEncoding: typeEncoding)

                        results.append(
                            InspectableProperty(
                                name: name,
                                getterName: name,
                                attributes: typeEncoding,
                                valueDescription: valueResult.valueDescription,
                                errorMessage: valueResult.errorMessage,
                                declaringClassName: declaringClassName,
                                isInherited: isInheritedMember(declaringClassName: declaringClassName),
                                isNSObjectMember: isNSObjectMember(declaringClassName),
                                isAccessibilityRelated: isAccessibilityRelated(name: name),
                                isClassMember: false,
                                isDirectIvar: true
                            )
                        )
                    }
                }
            }

            currentClass = class_getSuperclass(cls)
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func collectMethods(excluding propertyGetterNames: Set<String>) -> [InspectableMethod] {
        var results: [InspectableMethod] = []
        var seen = Set<String>()
        var currentClass: AnyClass? = methodTraversalRootClass

        while let cls = currentClass {
            let declaringClassName = displayClassName(for: cls)
            var count: UInt32 = 0
            guard let methods = class_copyMethodList(cls, &count) else {
                currentClass = class_getSuperclass(cls)
                continue
            }

            defer { free(methods) }

            for index in 0..<Int(count) {
                let method = methods[index]
                let selectorName = NSStringFromSelector(method_getName(method))
                guard seen.insert(selectorName).inserted else { continue }
                guard propertyGetterNames.contains(selectorName) == false else { continue }
                guard shouldIncludeMethod(named: selectorName) else { continue }

                let argumentCount = max(Int(method_getNumberOfArguments(method)) - 2, 0)
                let returnType = RuntimeInvocationEngine.methodReturnType(method)
                let returnKind = RuntimeInvocationEngine.returnKind(for: returnType)
                let blockedReason = invocationBlockedReason(
                    selectorName: selectorName,
                    argumentCount: argumentCount,
                    returnKind: returnKind
                )
                let isSafe = blockedReason == nil

                results.append(
                    InspectableMethod(
                        selectorName: selectorName,
                        returnTypeEncoding: returnType,
                        argumentCount: argumentCount,
                        returnKind: returnKind,
                        isSafeToInvoke: isSafe,
                        invocationBlockedReason: blockedReason,
                        declaringClassName: declaringClassName,
                        isInherited: isInheritedMember(declaringClassName: declaringClassName),
                        isNSObjectMember: isNSObjectMember(declaringClassName),
                        isAccessibilityRelated: isAccessibilityRelated(name: selectorName),
                        isPrivateMethod: selectorName.hasPrefix("_"),
                        isClassMethod: isInspectingClass
                    )
                )
            }

            currentClass = class_getSuperclass(cls)
        }

        return results.sorted { lhs, rhs in
            if lhs.isSafeToInvoke != rhs.isSafeToInvoke {
                return lhs.isSafeToInvoke && !rhs.isSafeToInvoke
            }
            return lhs.selectorName.localizedCaseInsensitiveCompare(rhs.selectorName) == .orderedAscending
        }
    }

    private func shouldIncludeMethod(named selectorName: String) -> Bool {
        let excluded = [
            ".cxx_destruct",
            ".cxx_construct",
            "dealloc",
            "init",
            "new",
            "copy",
            "mutableCopy",
            "retain",
            "release",
            "autorelease",
        ]
        return excluded.contains(selectorName) == false
    }

    private func isSafeMethodName(_ selectorName: String) -> Bool {
        let lowered = selectorName.lowercased()
        let denyPrefixes = [
            "set",
            "add",
            "remove",
            "insert",
            "delete",
            "present",
            "dismiss",
            "load",
            "reload",
            "register",
            "unregister",
            "post",
            "begin",
            "end",
        ]

        return denyPrefixes.allSatisfy { lowered.hasPrefix($0) == false }
    }

    private func invocationBlockedReason(
        selectorName: String,
        argumentCount: Int,
        returnKind: InspectableMethodReturnKind
    ) -> String? {
        if argumentCount > 0 {
            return "Requires \(argumentCount) argument\(argumentCount == 1 ? "" : "s")"
        }
        if returnKind == .unsupported {
            return "Unsupported return type"
        }
        if isSafeMethodName(selectorName) == false {
            return "Blocked by safety filter"
        }
        return nil
    }

    private func isInheritedMember(declaringClassName: String) -> Bool {
        declaringClassName != resolvedClassName
    }

    private func isNSObjectMember(_ declaringClassName: String) -> Bool {
        declaringClassName == "NSObject"
    }

    private func isAccessibilityRelated(name: String, alternateName: String? = nil) -> Bool {
        let candidates = [name, alternateName].compactMap { $0?.lowercased() }
        return candidates.contains { candidate in
            candidate.contains("accessibility") ||
            candidate.contains("isaccessibility") ||
            candidate.contains("accessibilityelement") ||
            candidate.contains("accessibilityidentifier") ||
            candidate.contains("accessibilitylabel") ||
            candidate.contains("accessibilityhint") ||
            candidate.contains("accessibilityvalue")
        }
    }

    private var propertyTraversalRootClass: AnyClass? {
        switch resolvedInstance.subjectKind {
        case .instance:
            guard let object = resolvedInstance.object else { return nil }
            return type(of: object)
        case .classObject:
            return object_getClass(resolvedInstance.targetClass)
        }
    }

    private var methodTraversalRootClass: AnyClass? {
        propertyTraversalRootClass
    }

    private func getterMethod(on cls: AnyClass, selector: Selector) -> Method? {
        class_getInstanceMethod(cls, selector)
    }

    private func invoke(selector: Selector, returnTypeEncoding: String) throws -> String {
        switch resolvedInstance.subjectKind {
        case .instance:
            guard let object = resolvedInstance.object else {
                throw RuntimeInvocationError.nilObjectReturn(NSStringFromSelector(selector))
            }
            return try RuntimeInvocationEngine.invokeInstanceMethod(
                on: object,
                selector: selector,
                returnTypeEncoding: returnTypeEncoding
            )
        case .classObject:
            return try RuntimeInvocationEngine.invokeClassMethod(
                on: resolvedInstance.targetClass,
                selector: selector,
                returnTypeEncoding: returnTypeEncoding
            )
        }
    }

    private func displayClassName(for cls: AnyClass) -> String {
        NSStringFromClass(cls)
    }

    private func describeIvarValue(
        object: AnyObject,
        ivar: Ivar,
        typeEncoding: String
    ) -> (valueDescription: String, errorMessage: String?) {
        guard let first = typeEncoding.first else {
            return ("", "Unknown ivar type")
        }

        guard first == "@" else {
            return ("", "Direct ivar reading currently supports object ivars only")
        }

        guard let value = object_getIvar(object, ivar) else {
            return ("nil", nil)
        }

        return (RuntimeInvocationEngine.describe(value: value), nil)
    }
}
