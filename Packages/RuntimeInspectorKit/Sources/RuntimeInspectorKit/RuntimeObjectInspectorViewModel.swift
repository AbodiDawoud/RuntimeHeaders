import Combine
import Foundation
import ObjectiveC.runtime

@MainActor
public final class RuntimeObjectInspectorViewModel: ObservableObject {
    public let resolvedInstance: ResolvedRuntimeInstance

    @Published public private(set) var properties: [InspectableProperty] = []
    @Published public private(set) var methods: [InspectableMethod] = []
    @Published public private(set) var lastInvocation: InvocationResult?

    public init(resolvedInstance: ResolvedRuntimeInstance) {
        self.resolvedInstance = resolvedInstance
        refresh()
    }

    public var resolvedClassName: String {
        resolvedInstance.displayName
    }

    public var isInspectingClass: Bool {
        resolvedInstance.subjectKind == .classObject
    }

    public func refresh() {
        let collectedProperties = collectProperties()
        let propertyNames = Set(collectedProperties.filter { $0.isDirectIvar == false }.map(\.getterName))
        properties = collectedProperties
        methods = collectMethods(excluding: propertyNames)
    }

    public func invoke(_ method: InspectableMethod) {
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

    public func read(_ property: InspectableProperty) {
        guard let index = properties.firstIndex(where: { $0.id == property.id }) else { return }

        let updatedProperty: InspectableProperty
        if property.isDirectIvar {
            updatedProperty = readDirectIvar(property)
        } else {
            updatedProperty = readGetter(property)
        }

        properties[index] = updatedProperty
    }

    private func collectProperties() -> [InspectableProperty] {
        var results: [InspectableProperty] = []
        var seen = Set<String>()
        var currentClass: AnyClass? = propertyTraversalRootClass

        while let cls = currentClass {
            let declaringClassName = NSStringFromClass(cls)
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

                    guard let method = class_getInstanceMethod(cls, getterSelector) else {
                        results.append(
                            makeProperty(
                                name: name,
                                getterName: getterName,
                                attributes: attributes,
                                valueDescription: "",
                                errorMessage: "Getter unavailable",
                                declaringClassName: declaringClassName,
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
                            makeProperty(
                                name: name,
                                getterName: getterName,
                                attributes: attributes,
                                valueDescription: "",
                                errorMessage: "Unsupported getter signature",
                                declaringClassName: declaringClassName,
                                isDirectIvar: false
                            )
                        )
                        continue
                    }

                    results.append(
                        makeProperty(
                            name: name,
                            getterName: getterName,
                            attributes: attributes,
                            valueDescription: "",
                            errorMessage: nil,
                            declaringClassName: declaringClassName,
                            isDirectIvar: false,
                            isValueLoaded: false
                        )
                    )
                }
            }

            if isInspectingClass == false, resolvedInstance.object != nil {
                var ivarCount: UInt32 = 0
                if let ivars = class_copyIvarList(cls, &ivarCount) {
                    defer { free(ivars) }

                    for index in 0..<Int(ivarCount) {
                        let ivar = ivars[index]
                        guard let ivarName = ivar_getName(ivar) else { continue }
                        let name = String(cString: ivarName)
                        guard seen.insert(name).inserted else { continue }

                        let typeEncoding = ivar_getTypeEncoding(ivar).map { String(cString: $0) } ?? ""
                        results.append(
                            makeProperty(
                                name: name,
                                getterName: name,
                                attributes: typeEncoding,
                                valueDescription: "",
                                errorMessage: nil,
                                declaringClassName: declaringClassName,
                                isDirectIvar: true,
                                isValueLoaded: false
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
        var currentClass: AnyClass? = propertyTraversalRootClass

        while let cls = currentClass {
            let declaringClassName = NSStringFromClass(cls)
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

                results.append(
                    InspectableMethod(
                        selectorName: selectorName,
                        returnTypeEncoding: returnType,
                        argumentCount: argumentCount,
                        returnKind: returnKind,
                        isSafeToInvoke: blockedReason == nil,
                        invocationBlockedReason: blockedReason,
                        declaringClassName: declaringClassName,
                        isInherited: declaringClassName != resolvedClassName,
                        isNSObjectMember: declaringClassName == "NSObject",
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

    private var propertyTraversalRootClass: AnyClass? {
        switch resolvedInstance.subjectKind {
        case .instance:
            guard let object = resolvedInstance.object else { return nil }
            return type(of: object)
        case .classObject:
            return object_getClass(resolvedInstance.targetClass)
        }
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

    private func makeProperty(
        name: String,
        getterName: String,
        attributes: String,
        valueDescription: String,
        errorMessage: String?,
        declaringClassName: String,
        isDirectIvar: Bool,
        isValueLoaded: Bool = true
    ) -> InspectableProperty {
        InspectableProperty(
            name: name,
            getterName: getterName,
            attributes: attributes,
            valueDescription: valueDescription,
            errorMessage: errorMessage,
            declaringClassName: declaringClassName,
            isInherited: declaringClassName != resolvedClassName,
            isNSObjectMember: declaringClassName == "NSObject",
            isAccessibilityRelated: isAccessibilityRelated(name: name, alternateName: getterName),
            isClassMember: isInspectingClass,
            isDirectIvar: isDirectIvar,
            isValueLoaded: isValueLoaded
        )
    }

    private func readGetter(_ property: InspectableProperty) -> InspectableProperty {
        do {
            let value = try invoke(
                selector: NSSelectorFromString(property.getterName),
                returnTypeEncoding: propertyReturnType(for: property)
            )

            return property.withValue(value, errorMessage: nil)
        } catch {
            return property.withValue("", errorMessage: error.localizedDescription)
        }
    }

    private func readDirectIvar(_ property: InspectableProperty) -> InspectableProperty {
        guard let object = resolvedInstance.object else {
            return property.withValue("", errorMessage: RuntimeInvocationError.nilObjectReturn(property.name).localizedDescription)
        }
        guard let declaringClass = NSClassFromString(property.declaringClassName),
              let ivar = class_getInstanceVariable(declaringClass, property.name)
        else {
            return property.withValue("", errorMessage: "Ivar unavailable")
        }

        let valueResult = describeIvarValue(object: object, ivar: ivar, typeEncoding: property.attributes)
        return property.withValue(valueResult.valueDescription, errorMessage: valueResult.errorMessage)
    }

    private func propertyReturnType(for property: InspectableProperty) throws -> String {
        let selector = NSSelectorFromString(property.getterName)
        let method: Method?

        switch resolvedInstance.subjectKind {
        case .instance:
            method = class_getInstanceMethod(propertyTraversalRootClass, selector)
        case .classObject:
            method = class_getClassMethod(resolvedInstance.targetClass, selector)
        }

        guard let method else {
            throw RuntimeInvocationError.missingMethod(property.getterName)
        }

        return RuntimeInvocationEngine.methodReturnType(method)
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

private extension InspectableProperty {
    func withValue(_ valueDescription: String, errorMessage: String?) -> InspectableProperty {
        InspectableProperty(
            name: name,
            getterName: getterName,
            attributes: attributes,
            valueDescription: valueDescription,
            errorMessage: errorMessage,
            declaringClassName: declaringClassName,
            isInherited: isInherited,
            isNSObjectMember: isNSObjectMember,
            isAccessibilityRelated: isAccessibilityRelated,
            isClassMember: isClassMember,
            isDirectIvar: isDirectIvar,
            isValueLoaded: true
        )
    }
}
