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

    func refresh() {
        let propertyNames = Set(collectProperties().map(\.getterName))
        properties = collectProperties()
        methods = collectMethods(excluding: propertyNames)
    }

    func invoke(_ method: InspectableMethod) {
        do {
            let selector = NSSelectorFromString(method.selectorName)
            let value = try RuntimeInvocationEngine.invokeInstanceMethod(
                on: resolvedInstance.object,
                selector: selector,
                returnTypeEncoding: method.returnTypeEncoding
            )
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
        var currentClass: AnyClass? = type(of: resolvedInstance.object)

        while let cls = currentClass {
            let declaringClassName = NSStringFromClass(cls)
            var count: UInt32 = 0
            guard let properties = class_copyPropertyList(cls, &count) else {
                currentClass = class_getSuperclass(cls)
                continue
            }

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
                        InspectableProperty(
                            name: name,
                            getterName: getterName,
                            attributes: attributes,
                            valueDescription: "",
                            errorMessage: "Getter unavailable",
                            declaringClassName: declaringClassName,
                            isInherited: isInheritedMember(declaringClassName: declaringClassName),
                            isNSObjectMember: isNSObjectMember(declaringClassName),
                            isAccessibilityRelated: isAccessibilityRelated(name: name, alternateName: getterName)
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
                            isAccessibilityRelated: isAccessibilityRelated(name: name, alternateName: getterName)
                        )
                    )
                    continue
                }

                do {
                    let value = try RuntimeInvocationEngine.invokeInstanceMethod(
                        on: resolvedInstance.object,
                        selector: getterSelector,
                        returnTypeEncoding: returnType
                    )
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
                            isAccessibilityRelated: isAccessibilityRelated(name: name, alternateName: getterName)
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
                            isAccessibilityRelated: isAccessibilityRelated(name: name, alternateName: getterName)
                        )
                    )
                }
            }

            currentClass = class_getSuperclass(cls)
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func collectMethods(excluding propertyGetterNames: Set<String>) -> [InspectableMethod] {
        var results: [InspectableMethod] = []
        var seen = Set<String>()
        var currentClass: AnyClass? = type(of: resolvedInstance.object)

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
                let isSafe = argumentCount == 0 &&
                    returnKind != .unsupported &&
                    isSafeMethodName(selectorName)

                results.append(
                    InspectableMethod(
                        selectorName: selectorName,
                        returnTypeEncoding: returnType,
                        argumentCount: argumentCount,
                        returnKind: returnKind,
                        isSafeToInvoke: isSafe,
                        declaringClassName: declaringClassName,
                        isInherited: isInheritedMember(declaringClassName: declaringClassName),
                        isNSObjectMember: isNSObjectMember(declaringClassName),
                        isAccessibilityRelated: isAccessibilityRelated(name: selectorName)
                    )
                )
            }

            currentClass = class_getSuperclass(cls)
        }

        return results
            .filter(\.isSafeToInvoke)
            .sorted { $0.selectorName.localizedCaseInsensitiveCompare($1.selectorName) == .orderedAscending }
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
            "_",
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
}
