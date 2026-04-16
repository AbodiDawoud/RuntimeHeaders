import Foundation

public enum RuntimeInspectionSubjectKind {
    case instance
    case classObject
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
        isValueLoaded: Bool = true
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

    public init(selectorName: String, valueDescription: String, errorMessage: String?) {
        self.selectorName = selectorName
        self.valueDescription = valueDescription
        self.errorMessage = errorMessage
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
