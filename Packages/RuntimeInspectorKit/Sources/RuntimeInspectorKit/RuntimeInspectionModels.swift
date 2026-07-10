import Foundation

public enum RuntimeInspectionSubjectKind {
    case instance
    case classObject
}

public struct InspectableObjectReference: Identifiable {
    public let className: String
    public let displayName: String
    public let acquisitionDescription: String
    public let pointerDescription: String
    public let resolvedInstance: ResolvedRuntimeInstance

    public init(object: AnyObject, acquisitionDescription: String) {
        let targetClass: AnyClass = type(of: object)
        let pointerDescription = String(describing: Unmanaged.passUnretained(object).toOpaque())
        let className = NSStringFromClass(targetClass)
        let resolvedInstance = ResolvedRuntimeInstance(
            className: className,
            selectorName: acquisitionDescription,
            acquisitionDescription: acquisitionDescription,
            subjectKind: .instance,
            targetClass: targetClass,
            object: object
        )

        self.className = className
        self.displayName = resolvedInstance.displayName
        self.acquisitionDescription = acquisitionDescription
        self.pointerDescription = pointerDescription
        self.resolvedInstance = resolvedInstance
    }

    public var id: String {
        "\(className):\(pointerDescription):\(acquisitionDescription)"
    }
}

public struct ResolvedRuntimeInstance: Identifiable {
    public let className: String
    public let selectorName: String
    public let acquisitionDescription: String
    public let subjectKind: RuntimeInspectionSubjectKind
    public let targetClass: AnyClass
    public let object: AnyObject?

    public init(
        className: String,
        selectorName: String,
        acquisitionDescription: String,
        subjectKind: RuntimeInspectionSubjectKind,
        targetClass: AnyClass,
        object: AnyObject?
    ) {
        self.className = className
        self.selectorName = selectorName
        self.acquisitionDescription = acquisitionDescription
        self.subjectKind = subjectKind
        self.targetClass = targetClass
        self.object = object
    }

    public var displayName: String {
        switch subjectKind {
        case .instance:
            guard let object else { return className }
            return NSStringFromClass(type(of: object))
        case .classObject:
            return NSStringFromClass(targetClass)
        }
    }

    public var pointerDescription: String? {
        switch subjectKind {
        case .instance:
            guard let object else { return nil }
            let pointer = Unmanaged.passUnretained(object).toOpaque()
            return String(describing: pointer)
        case .classObject:
            let pointer = unsafeBitCast(targetClass, to: UnsafeRawPointer.self)
            return String(describing: pointer)
        }
    }

    public var inspectorTitle: String {
        switch subjectKind {
        case .instance: "Object Inspector"
        case .classObject: "Class Members"
        }
    }

    public var subjectDescription: String {
        switch subjectKind {
        case .instance: "Instance"
        case .classObject: "Class"
        }
    }

    public var id: String {
        className
    }
}

public enum InspectableMethodReturnKind: String {
    case void
    case object
    case bool
    case integer
    case unsignedInteger
    case floatingPoint
    case unsupported
}

public enum InspectableMethodArgumentKind: String {
    case bool
    case integer
    case unsignedInteger
    case floatingPoint
    case string
    case completionHandler
    case unsupported
}

public struct InspectableMethodArgument: Identifiable {
    public let index: Int
    public let typeEncoding: String
    public let kind: InspectableMethodArgumentKind

    public init(index: Int, typeEncoding: String, kind: InspectableMethodArgumentKind) {
        self.index = index
        self.typeEncoding = typeEncoding
        self.kind = kind
    }

    public var id: Int {
        index
    }

    public var displayName: String {
        "Argument \(index + 1)"
    }
}

public enum RuntimeInvocationArgument {
    case bool(Bool)
    case integer(Int)
    case unsignedInteger(UInt)
    case double(Double)
    case string(String)
    case completionHandler(RuntimeCompletionHandler)
}

public enum RuntimeCompletionHandlerSignature: String, CaseIterable, Identifiable {
    case void
    case object
    case objectError

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .void:
            return "() -> Void"
        case .object:
            return "(Any?) -> Void"
        case .objectError:
            return "(Any?, NSError?) -> Void"
        }
    }
}

public struct RuntimeCompletionHandlerValue: Identifiable {
    public let label: String
    public let valueDescription: String
    public let objectReference: InspectableObjectReference?
    public let collectionReference: InspectableCollectionReference?

    public init(
        label: String,
        valueDescription: String,
        objectReference: InspectableObjectReference? = nil,
        collectionReference: InspectableCollectionReference? = nil
    ) {
        self.label = label
        self.valueDescription = valueDescription
        self.objectReference = objectReference
        self.collectionReference = collectionReference
    }

    public var id: String {
        label
    }
}

public struct RuntimeCompletionHandlerEvent {
    public let handlerID: UUID
    public let signature: RuntimeCompletionHandlerSignature
    public let values: [RuntimeCompletionHandlerValue]

    public init(
        handlerID: UUID,
        signature: RuntimeCompletionHandlerSignature,
        values: [RuntimeCompletionHandlerValue]
    ) {
        self.handlerID = handlerID
        self.signature = signature
        self.values = values
    }
}

public final class RuntimeCompletionHandler: Identifiable {
    public let id: UUID
    public let signature: RuntimeCompletionHandlerSignature
    let blockObject: AnyObject

    public init(
        signature: RuntimeCompletionHandlerSignature,
        eventHandler: @escaping (RuntimeCompletionHandlerEvent) -> Void
    ) {
        let id = UUID()
        self.id = id
        self.signature = signature

        switch signature {
        case .void:
            let block: @convention(block) () -> Void = {
                eventHandler(
                    RuntimeCompletionHandlerEvent(
                        handlerID: id,
                        signature: signature,
                        values: []
                    )
                )
            }
            blockObject = block as AnyObject
        case .object:
            let block: @convention(block) (Any?) -> Void = { value in
                eventHandler(
                    RuntimeCompletionHandlerEvent(
                        handlerID: id,
                        signature: signature,
                        values: [
                            RuntimeCompletionHandlerValue(
                                label: "value",
                                valueDescription: Self.describe(optionalValue: value),
                                objectReference: Self.objectReference(for: value, acquisitionDescription: "completion value"),
                                collectionReference: Self.collectionReference(for: value, acquisitionDescription: "completion value")
                            )
                        ]
                    )
                )
            }
            blockObject = block as AnyObject
        case .objectError:
            let block: @convention(block) (Any?, NSError?) -> Void = { value, error in
                eventHandler(
                    RuntimeCompletionHandlerEvent(
                        handlerID: id,
                        signature: signature,
                        values: [
                            RuntimeCompletionHandlerValue(
                                label: "value",
                                valueDescription: Self.describe(optionalValue: value),
                                objectReference: Self.objectReference(for: value, acquisitionDescription: "completion value"),
                                collectionReference: Self.collectionReference(for: value, acquisitionDescription: "completion value")
                            ),
                            RuntimeCompletionHandlerValue(
                                label: "error",
                                valueDescription: Self.describe(optionalValue: error),
                                objectReference: Self.objectReference(for: error, acquisitionDescription: "completion error"),
                                collectionReference: Self.collectionReference(for: error, acquisitionDescription: "completion error")
                            )
                        ]
                    )
                )
            }
            blockObject = block as AnyObject
        }
    }

    private static func describe(optionalValue value: Any?) -> String {
        guard let value else { return "nil" }
        if let error = value as? NSError {
            return "\(error.domain)(\(error.code)): \(error.localizedDescription)"
        }
        return RuntimeInvocationEngine.describe(value: value)
    }

    private static func objectReference(
        for value: Any?,
        acquisitionDescription: String
    ) -> InspectableObjectReference? {
        guard let object = value as AnyObject? else { return nil }
        return InspectableObjectReference(object: object, acquisitionDescription: acquisitionDescription)
    }

    private static func collectionReference(
        for value: Any?,
        acquisitionDescription: String
    ) -> InspectableCollectionReference? {
        guard let object = value as AnyObject? else { return nil }
        return InspectableCollectionReference(object: object, acquisitionDescription: acquisitionDescription)
    }
}

public struct InspectableProperty: Identifiable {
    public let name: String
    public let getterName: String
    public let attributes: String
    public let valueDescription: String
    public let errorMessage: String?
    public let declaringClassName: String
    public let isInherited: Bool
    public let isNSObjectMember: Bool
    public let isAccessibilityRelated: Bool
    public let isClassMember: Bool
    public let isDirectIvar: Bool
    public let isValueLoaded: Bool
    public let objectReference: InspectableObjectReference?
    public let collectionReference: InspectableCollectionReference?

    public init(
        name: String,
        getterName: String,
        attributes: String,
        valueDescription: String,
        errorMessage: String?,
        declaringClassName: String,
        isInherited: Bool,
        isNSObjectMember: Bool,
        isAccessibilityRelated: Bool,
        isClassMember: Bool,
        isDirectIvar: Bool,
        isValueLoaded: Bool = true,
        objectReference: InspectableObjectReference? = nil,
        collectionReference: InspectableCollectionReference? = nil
    ) {
        self.name = name
        self.getterName = getterName
        self.attributes = attributes
        self.valueDescription = valueDescription
        self.errorMessage = errorMessage
        self.declaringClassName = declaringClassName
        self.isInherited = isInherited
        self.isNSObjectMember = isNSObjectMember
        self.isAccessibilityRelated = isAccessibilityRelated
        self.isClassMember = isClassMember
        self.isDirectIvar = isDirectIvar
        self.isValueLoaded = isValueLoaded
        self.objectReference = objectReference
        self.collectionReference = collectionReference
    }

    public var id: String {
        "\(isDirectIvar ? "ivar" : "property"):\(name)"
    }

    public var isReadable: Bool {
        isValueLoaded && errorMessage == nil
    }
}

public struct InspectableMethod: Identifiable {
    public let selectorName: String
    public let returnTypeEncoding: String
    public let argumentCount: Int
    public let arguments: [InspectableMethodArgument]
    public let returnKind: InspectableMethodReturnKind
    public let isSafeToInvoke: Bool
    public let invocationBlockedReason: String?
    public let declaringClassName: String
    public let isInherited: Bool
    public let isNSObjectMember: Bool
    public let isAccessibilityRelated: Bool
    public let isPrivateMethod: Bool
    public let isClassMethod: Bool

    public init(
        selectorName: String,
        returnTypeEncoding: String,
        argumentCount: Int,
        arguments: [InspectableMethodArgument],
        returnKind: InspectableMethodReturnKind,
        isSafeToInvoke: Bool,
        invocationBlockedReason: String?,
        declaringClassName: String,
        isInherited: Bool,
        isNSObjectMember: Bool,
        isAccessibilityRelated: Bool,
        isPrivateMethod: Bool,
        isClassMethod: Bool
    ) {
        self.selectorName = selectorName
        self.returnTypeEncoding = returnTypeEncoding
        self.argumentCount = argumentCount
        self.arguments = arguments
        self.returnKind = returnKind
        self.isSafeToInvoke = isSafeToInvoke
        self.invocationBlockedReason = invocationBlockedReason
        self.declaringClassName = declaringClassName
        self.isInherited = isInherited
        self.isNSObjectMember = isNSObjectMember
        self.isAccessibilityRelated = isAccessibilityRelated
        self.isPrivateMethod = isPrivateMethod
        self.isClassMethod = isClassMethod
    }

    public var id: String {
        selectorName
    }
}

public struct InvocationResult: Identifiable {
    public let selectorName: String
    public let valueDescription: String
    public let errorMessage: String?
    public let objectReferences: [InspectableObjectReference]
    public let collectionReferences: [InspectableCollectionReference]

    public init(
        selectorName: String,
        valueDescription: String,
        errorMessage: String?,
        objectReferences: [InspectableObjectReference] = [],
        collectionReferences: [InspectableCollectionReference] = []
    ) {
        self.selectorName = selectorName
        self.valueDescription = valueDescription
        self.errorMessage = errorMessage
        self.objectReferences = objectReferences
        self.collectionReferences = collectionReferences
    }

    public var id: String {
        selectorName + valueDescription
    }

    public var isSuccess: Bool {
        errorMessage == nil
    }
}

public enum RuntimeInstanceCandidateKind {
    case classGetter
    case zeroArgumentInitializer
}

public struct RuntimeInstanceCandidate: Identifiable {
    public let selectorName: String
    public let displayName: String
    public let subtitle: String
    public let kind: RuntimeInstanceCandidateKind

    public init(
        selectorName: String,
        displayName: String,
        subtitle: String,
        kind: RuntimeInstanceCandidateKind
    ) {
        self.selectorName = selectorName
        self.displayName = displayName
        self.subtitle = subtitle
        self.kind = kind
    }

    public var id: String {
        switch kind {
        case .classGetter:
            "getter:\(selectorName)"
        case .zeroArgumentInitializer:
            "initializer:\(selectorName)"
        }
    }
}

public struct RuntimeInstanceResolutionOptions {
    public let autoResolvedInstance: ResolvedRuntimeInstance?
    public let manualCandidates: [RuntimeInstanceCandidate]

    public init(
        autoResolvedInstance: ResolvedRuntimeInstance?,
        manualCandidates: [RuntimeInstanceCandidate]
    ) {
        self.autoResolvedInstance = autoResolvedInstance
        self.manualCandidates = manualCandidates
    }
}
