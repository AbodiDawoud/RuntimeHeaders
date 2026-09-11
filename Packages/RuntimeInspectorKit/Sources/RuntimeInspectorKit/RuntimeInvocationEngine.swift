import Foundation
import ObjectiveC.runtime
import RuntimeInvocationBridge

enum RuntimeInvocationEngine {
    static func invokeClassObjectMethod(on cls: AnyClass, selector: Selector) throws -> AnyObject {
        guard let method = class_getClassMethod(cls, selector) else {
            throw RuntimeInvocationError.missingMethod(NSStringFromSelector(selector))
        }
        let returnType = methodReturnType(method)
        guard returnKind(for: returnType) == .object else {
            throw RuntimeInvocationError.unsupportedReturnType(returnType)
        }
        guard let result = try send(on: cls as AnyObject, selector: selector, arguments: []) else {
            throw RuntimeInvocationError.nilObjectReturn(NSStringFromSelector(selector))
        }
        return result
    }

    static func createInstance(of cls: AnyClass) throws -> AnyObject {
        var result: AnyObject?
        if let error = RICreateInstance(cls, &result) { throw error }
        guard let result else { throw RuntimeInvocationError.nilObjectReturn("init") }
        return result
    }

    static func invokeInstanceMethod(
        on object: AnyObject,
        selector: Selector,
        returnTypeEncoding: String,
        arguments: [RuntimeInvocationArgument] = []
    ) throws -> RuntimeInvocationOutput {
        try invoke(on: object, selector: selector, returnTypeEncoding: returnTypeEncoding, arguments: arguments)
    }

    static func invokeClassMethod(
        on cls: AnyClass,
        selector: Selector,
        returnTypeEncoding: String,
        arguments: [RuntimeInvocationArgument] = []
    ) throws -> RuntimeInvocationOutput {
        try invoke(on: cls as AnyObject, selector: selector, returnTypeEncoding: returnTypeEncoding, arguments: arguments)
    }

    private static func invoke(
        on receiver: AnyObject,
        selector: Selector,
        returnTypeEncoding: String,
        arguments: [RuntimeInvocationArgument]
    ) throws -> RuntimeInvocationOutput {
        guard let method = class_getInstanceMethod(object_getClass(receiver), selector) else {
            throw RuntimeInvocationError.missingMethod(NSStringFromSelector(selector))
        }
        let returnType = normalizedTypeEncoding(methodReturnType(method))
        guard returnType == normalizedTypeEncoding(returnTypeEncoding) else {
            throw RuntimeInvocationError.signatureChanged(NSStringFromSelector(selector))
        }
        let kind = returnKind(for: returnType)
        guard kind != .unsupported else {
            throw RuntimeInvocationError.unsupportedReturnType(returnType)
        }
        let encodings = methodArgumentTypes(method)
        guard arguments.count == encodings.count else {
            throw RuntimeInvocationError.invalidArgumentList(expected: encodings.count, actual: arguments.count)
        }
        guard arguments.count <= 3 else {
            throw RuntimeInvocationError.unsupportedArgumentCount(arguments.count)
        }
        let prepared = try zip(arguments, encodings).map { try prepare($0.0, encoding: $0.1) }
        let result = try send(on: receiver, selector: selector, arguments: prepared)

        switch kind {
        case .void:
            return RuntimeInvocationOutput(valueDescription: "Completed")
        case .object:
            return RuntimeInvocationOutput(valueDescription: result.map { describe(value: $0) } ?? "nil", object: result)
        case .bool:
            return RuntimeInvocationOutput(valueDescription: (result as? NSNumber)?.boolValue == true ? "true" : "false")
        default:
            return RuntimeInvocationOutput(valueDescription: result.map { describe(value: $0) } ?? "nil")
        }
    }

    private static func send(on receiver: AnyObject, selector: Selector, arguments: [AnyObject]) throws -> AnyObject? {
        var result: AnyObject?
        if let error = RIInvoke(receiver, selector, arguments, &result) { throw error }
        return result
    }

    static func returnKind(for encoding: String) -> InspectableMethodReturnKind {
        switch normalizedTypeEncoding(encoding).first {
        case "v": .void
        case "@": .object
        case "B": .bool
        case "q", "i", "s", "l": .integer
        case "Q", "I", "S", "L": .unsignedInteger
        case "d", "f": .floatingPoint
        default: .unsupported
        }
    }

    static func argumentKind(for encoding: String) -> InspectableMethodArgumentKind {
        let encoding = normalizedTypeEncoding(encoding)
        switch encoding.first {
        case "B": return .bool
        case "q", "i", "s", "l": return .integer
        case "Q", "I", "S", "L": return .unsignedInteger
        case "d": return .floatingPoint
        case "@":
            if encoding.hasPrefix("@?") { return .completionHandler }
            return encoding == "@" || encoding.contains("NSString") || encoding.contains("NSMutableString")
                ? .string : .unsupported
        default: return .unsupported
        }
    }

    static func methodArgumentTypes(_ method: Method) -> [String] {
        let count = Int(method_getNumberOfArguments(method))
        guard count > 2 else { return [] }
        return (2..<count).map { index in
            guard let encoding = method_copyArgumentType(method, UInt32(index)) else { return "" }
            defer { free(encoding) }
            return String(cString: encoding)
        }
    }

    static func methodReturnType(_ method: Method) -> String {
        let encoding = method_copyReturnType(method)
        defer { free(encoding) }
        return String(cString: encoding)
    }

    static func describe(value: Any) -> String {
        switch value {
        case let string as String:
            string
        case let number as NSNumber:
            number.stringValue
        case let url as URL:
            url.absoluteString
        case let array as NSArray:
            "[\(array.count) items]"
        case let dictionary as NSDictionary:
            "[\(dictionary.count) pairs]"
        case let set as NSSet:
            "[\(set.count) items]"
        case let set as NSOrderedSet:
            "[\(set.count) items]"
        default:
            String(describing: value)
        }
    }

    private static func normalizedTypeEncoding(_ encoding: String) -> String {
        String(encoding.drop(while: { "rnNoORV".contains($0) }))
    }

    private static func prepare(_ argument: RuntimeInvocationArgument, encoding: String) throws -> AnyObject {
        let normalized = normalizedTypeEncoding(encoding)
        switch (argument, argumentKind(for: normalized)) {
        case (.bool(let value), .bool):
            return NSNumber(value: value)
        case (.integer(let value), .integer):
            let fits: Bool
            switch normalized {
            case "s": fits = Int16(exactly: value) != nil
            case "i", "l": fits = Int32(exactly: value) != nil
            default: fits = Int64(exactly: value) != nil
            }
            guard fits else { throw RuntimeInvocationError.argumentOutOfRange(encoding) }
            return NSNumber(value: value)
        case (.unsignedInteger(let value), .unsignedInteger):
            let fits: Bool
            switch normalized {
            case "S": fits = UInt16(exactly: value) != nil
            case "I", "L": fits = UInt32(exactly: value) != nil
            default: fits = UInt64(exactly: value) != nil
            }
            guard fits else { throw RuntimeInvocationError.argumentOutOfRange(encoding) }
            return NSNumber(value: value)
        case (.double(let value), .floatingPoint):
            return NSNumber(value: value)
        case (.string(let value), .string):
            return value as NSString
        case (.completionHandler(let handler), .completionHandler):
            return handler.blockObject
        default:
            throw RuntimeInvocationError.unsupportedArgumentType(encoding)
        }
    }
}

enum RuntimeInvocationError: LocalizedError {
    case missingMethod(String)
    case unsupportedReturnType(String)
    case unsupportedArgumentType(String)
    case unsupportedArgumentCount(Int)
    case invalidArgumentList(expected: Int, actual: Int)
    case argumentOutOfRange(String)
    case signatureChanged(String)
    case nilObjectReturn(String)

    var errorDescription: String? {
        switch self {
        case .missingMethod(let selectorName):
            "Missing method '\(selectorName)'."
        case .unsupportedReturnType(let encoding):
            "Unsupported return type '\(encoding)'."
        case .unsupportedArgumentType(let encoding):
            "Unsupported argument type '\(encoding)'."
        case .unsupportedArgumentCount(let count):
            "Calling methods with \(count) arguments is not supported yet."
        case .invalidArgumentList(let expected, let actual):
            "Expected \(expected) argument\(expected == 1 ? "" : "s"), received \(actual)."
        case .argumentOutOfRange(let encoding):
            "The value is outside the range of argument type '\(encoding)'."
        case .signatureChanged(let selectorName):
            "The signature of '\(selectorName)' changed. Refresh the inspector."
        case .nilObjectReturn(let selectorName):
            "'\(selectorName)' returned nil."
        }
    }
}

struct RuntimeInvocationOutput {
    let valueDescription: String
    let object: AnyObject?

    init(valueDescription: String, object: AnyObject? = nil) {
        self.valueDescription = valueDescription
        self.object = object
    }
}
