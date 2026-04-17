import Darwin
import Foundation
import ObjectiveC.runtime

enum RuntimeInvocationEngine {
    private static let objcMessageSendPointer: UnsafeMutableRawPointer = {
        guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend") else {
            fatalError("Failed to resolve objc_msgSend")
        }
        return pointer
    }()

    static func invokeClassObjectMethod(on cls: AnyClass, selector: Selector) throws -> AnyObject {
        guard let method = class_getClassMethod(cls, selector) else {
            throw RuntimeInvocationError.missingMethod(NSStringFromSelector(selector))
        }

        let returnType = methodReturnType(method)
        guard returnKind(for: returnType) == .object else {
            throw RuntimeInvocationError.unsupportedReturnType(returnType)
        }

        typealias Function = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
        let function = unsafeBitCast(objcMessageSendPointer, to: Function.self)

        guard let object = function(cls, selector)?.takeUnretainedValue() else {
            throw RuntimeInvocationError.nilObjectReturn(NSStringFromSelector(selector))
        }

        return object
    }

    static func invokeInstanceObjectMethod(on object: AnyObject, selector: Selector) throws -> AnyObject {
        guard let method = class_getInstanceMethod(type(of: object), selector) else {
            throw RuntimeInvocationError.missingMethod(NSStringFromSelector(selector))
        }

        let returnType = methodReturnType(method)
        guard returnKind(for: returnType) == .object else {
            throw RuntimeInvocationError.unsupportedReturnType(returnType)
        }

        typealias Function = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        let function = unsafeBitCast(objcMessageSendPointer, to: Function.self)

        guard let result = function(object, selector)?.takeUnretainedValue() else {
            throw RuntimeInvocationError.nilObjectReturn(NSStringFromSelector(selector))
        }

        return result
    }

    static func invokeInstanceMethod(
        on object: AnyObject,
        selector: Selector,
        returnTypeEncoding: String
    ) throws -> String {
        try invokeInstanceMethod(
            on: object,
            selector: selector,
            returnTypeEncoding: returnTypeEncoding,
            arguments: []
        )
    }

    static func invokeInstanceMethod(
        on object: AnyObject,
        selector: Selector,
        returnTypeEncoding: String,
        arguments: [RuntimeInvocationArgument]
    ) throws -> String {
        let methodName = NSStringFromSelector(selector)
        let preparedArguments = try prepare(arguments)
        switch returnKind(for: returnTypeEncoding) {
        case .void:
            try invokeVoid(on: object, selector: selector, arguments: preparedArguments)
            return "Completed"
        case .object:
            guard let result = try invokeObject(on: object, selector: selector, arguments: preparedArguments) else {
                throw RuntimeInvocationError.nilObjectReturn(methodName)
            }
            return describe(value: result)
        case .bool:
            return try invokeBool(on: object, selector: selector, arguments: preparedArguments) ? "true" : "false"
        case .integer:
            return String(try invokeInt(on: object, selector: selector, arguments: preparedArguments))
        case .unsignedInteger:
            return String(try invokeUInt(on: object, selector: selector, arguments: preparedArguments))
        case .floatingPoint:
            if returnTypeEncoding == "f" {
                return String(try invokeFloat(on: object, selector: selector, arguments: preparedArguments))
            } else {
                return String(try invokeDouble(on: object, selector: selector, arguments: preparedArguments))
            }
        case .unsupported:
            throw RuntimeInvocationError.unsupportedReturnType(returnTypeEncoding)
        }
    }

    static func invokeClassMethod(
        on cls: AnyClass,
        selector: Selector,
        returnTypeEncoding: String
    ) throws -> String {
        try invokeClassMethod(
            on: cls,
            selector: selector,
            returnTypeEncoding: returnTypeEncoding,
            arguments: []
        )
    }

    static func invokeClassMethod(
        on cls: AnyClass,
        selector: Selector,
        returnTypeEncoding: String,
        arguments: [RuntimeInvocationArgument]
    ) throws -> String {
        let receiver = cls as AnyObject
        let preparedArguments = try prepare(arguments)
        let methodName = NSStringFromSelector(selector)
        switch returnKind(for: returnTypeEncoding) {
        case .void:
            try invokeVoid(on: receiver, selector: selector, arguments: preparedArguments)
            return "Completed"
        case .object:
            guard let result = try invokeObject(on: receiver, selector: selector, arguments: preparedArguments) else {
                throw RuntimeInvocationError.nilObjectReturn(methodName)
            }
            return describe(value: result)
        case .bool:
            return try invokeBool(on: receiver, selector: selector, arguments: preparedArguments) ? "true" : "false"
        case .integer:
            return String(try invokeInt(on: receiver, selector: selector, arguments: preparedArguments))
        case .unsignedInteger:
            return String(try invokeUInt(on: receiver, selector: selector, arguments: preparedArguments))
        case .floatingPoint:
            if returnTypeEncoding == "f" {
                return String(try invokeFloat(on: receiver, selector: selector, arguments: preparedArguments))
            } else {
                return String(try invokeDouble(on: receiver, selector: selector, arguments: preparedArguments))
            }
        case .unsupported:
            throw RuntimeInvocationError.unsupportedReturnType(returnTypeEncoding)
        }
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
        let normalizedEncoding = normalizedTypeEncoding(encoding)
        switch normalizedEncoding.first {
        case "B":
            return .bool
        case "q", "i", "s", "l":
            return .integer
        case "Q", "I", "S", "L":
            return .unsignedInteger
        case "d":
            return .floatingPoint
        case "@":
            return isStringObjectEncoding(normalizedEncoding) ? .string : .unsupported
        default:
            return .unsupported
        }
    }

    static func methodArgumentTypes(_ method: Method) -> [String] {
        let count = Int(method_getNumberOfArguments(method))
        guard count > 2 else { return [] }

        return (2..<count).map { index in
            var buffer = [CChar](repeating: 0, count: 128)
            method_getArgumentType(method, UInt32(index), &buffer, buffer.count)
            return String(cString: buffer)
        }
    }

    static func methodReturnType(_ method: Method) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        method_getReturnType(method, &buffer, buffer.count)
        return String(cString: buffer)
    }

    static func describe(value: Any) -> String {
        switch value {
        case let string as String:
            string
        case let number as NSNumber:
            number.stringValue
        case let url as URL:
            url.absoluteString
        case let array as [Any]:
            "[\(array.count) items] " + String(describing: array)
        case let dictionary as [AnyHashable: Any]:
            "[\(dictionary.count) pairs] " + String(describing: dictionary)
        default:
            String(describing: value)
        }
    }
}

enum RuntimeInvocationError: LocalizedError {
    case missingMethod(String)
    case unsupportedReturnType(String)
    case unsupportedArgumentType(String)
    case unsupportedArgumentCount(Int)
    case invalidArgumentList(expected: Int, actual: Int)
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
        case .nilObjectReturn(let selectorName):
            "'\(selectorName)' returned nil."
        }
    }
}

private struct PreparedInvocationArgument {
    let kind: Kind
    let retainedObject: AnyObject?

    init(kind: Kind, retainedObject: AnyObject? = nil) {
        self.kind = kind
        self.retainedObject = retainedObject
    }

    enum Kind {
        case general(UInt64)
        case double(Double)
    }

    var pattern: Character {
        switch kind {
        case .general:
            return "g"
        case .double:
            return "d"
        }
    }
}

private extension RuntimeInvocationEngine {
    static func normalizedTypeEncoding(_ encoding: String) -> String {
        let qualifiers = Set("rnNoORV")
        var result = encoding
        while let first = result.first, qualifiers.contains(first) {
            result.removeFirst()
        }
        return result
    }

    static func isStringObjectEncoding(_ encoding: String) -> Bool {
        encoding == "@" || encoding.contains("NSString") || encoding.contains("NSMutableString")
    }

    static func prepare(_ arguments: [RuntimeInvocationArgument]) throws -> [PreparedInvocationArgument] {
        guard arguments.count <= 3 else {
            throw RuntimeInvocationError.unsupportedArgumentCount(arguments.count)
        }

        return arguments.map { argument in
            switch argument {
            case .bool(let value):
                return PreparedInvocationArgument(kind: .general(value ? 1 : 0))
            case .integer(let value):
                return PreparedInvocationArgument(kind: .general(UInt64(bitPattern: Int64(value))))
            case .unsignedInteger(let value):
                return PreparedInvocationArgument(kind: .general(UInt64(value)))
            case .double(let value):
                return PreparedInvocationArgument(kind: .double(value))
            case .string(let value):
                let object = value as NSString
                let pointer = Unmanaged.passUnretained(object).toOpaque()
                return PreparedInvocationArgument(
                    kind: .general(UInt64(UInt(bitPattern: pointer))),
                    retainedObject: object
                )
            }
        }
    }

    static func pattern(for arguments: [PreparedInvocationArgument]) throws -> String {
        guard arguments.count <= 3 else {
            throw RuntimeInvocationError.unsupportedArgumentCount(arguments.count)
        }
        return String(arguments.map(\.pattern))
    }

    static func general(_ arguments: [PreparedInvocationArgument], _ index: Int) -> UInt64 {
        guard case .general(let value) = arguments[index].kind else { return 0 }
        return value
    }

    static func double(_ arguments: [PreparedInvocationArgument], _ index: Int) -> Double {
        guard case .double(let value) = arguments[index].kind else { return 0 }
        return value
    }

    static func invokeVoid(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws {
        switch try pattern(for: arguments) {
        case "":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector) -> Void).self)
            function(object, selector)
        case "g":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64) -> Void).self)
            function(object, selector, general(arguments, 0))
        case "d":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double) -> Void).self)
            function(object, selector, double(arguments, 0))
        case "gg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64) -> Void).self)
            function(object, selector, general(arguments, 0), general(arguments, 1))
        case "gd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double) -> Void).self)
            function(object, selector, general(arguments, 0), double(arguments, 1))
        case "dg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64) -> Void).self)
            function(object, selector, double(arguments, 0), general(arguments, 1))
        case "dd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double) -> Void).self)
            function(object, selector, double(arguments, 0), double(arguments, 1))
        case "ggg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64, UInt64) -> Void).self)
            function(object, selector, general(arguments, 0), general(arguments, 1), general(arguments, 2))
        case "ggd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64, Double) -> Void).self)
            function(object, selector, general(arguments, 0), general(arguments, 1), double(arguments, 2))
        case "gdg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double, UInt64) -> Void).self)
            function(object, selector, general(arguments, 0), double(arguments, 1), general(arguments, 2))
        case "gdd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double, Double) -> Void).self)
            function(object, selector, general(arguments, 0), double(arguments, 1), double(arguments, 2))
        case "dgg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64, UInt64) -> Void).self)
            function(object, selector, double(arguments, 0), general(arguments, 1), general(arguments, 2))
        case "dgd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64, Double) -> Void).self)
            function(object, selector, double(arguments, 0), general(arguments, 1), double(arguments, 2))
        case "ddg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double, UInt64) -> Void).self)
            function(object, selector, double(arguments, 0), double(arguments, 1), general(arguments, 2))
        case "ddd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double, Double) -> Void).self)
            function(object, selector, double(arguments, 0), double(arguments, 1), double(arguments, 2))
        default:
            throw RuntimeInvocationError.unsupportedArgumentCount(arguments.count)
        }
    }

    static func invokeObject(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws -> AnyObject? {
        let result = try invokeGeneralReturn(on: object, selector: selector, arguments: arguments)
        guard result != 0,
              let pointer = UnsafeRawPointer(bitPattern: UInt(result))
        else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }

    static func invokeBool(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws -> Bool {
        try invokeGeneralReturn(on: object, selector: selector, arguments: arguments) != 0
    }

    static func invokeInt(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws -> Int {
        Int(bitPattern: UInt(try invokeGeneralReturn(on: object, selector: selector, arguments: arguments)))
    }

    static func invokeUInt(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws -> UInt {
        UInt(try invokeGeneralReturn(on: object, selector: selector, arguments: arguments))
    }

    static func invokeFloat(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws -> Float {
        try invokeFloatReturn(on: object, selector: selector, arguments: arguments)
    }

    static func invokeDouble(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws -> Double {
        try invokeDoubleReturn(on: object, selector: selector, arguments: arguments)
    }

    static func invokeGeneralReturn(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws -> UInt64 {
        switch try pattern(for: arguments) {
        case "":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector) -> UInt64).self)
            return function(object, selector)
        case "g":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64) -> UInt64).self)
            return function(object, selector, general(arguments, 0))
        case "d":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double) -> UInt64).self)
            return function(object, selector, double(arguments, 0))
        case "gg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64) -> UInt64).self)
            return function(object, selector, general(arguments, 0), general(arguments, 1))
        case "gd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double) -> UInt64).self)
            return function(object, selector, general(arguments, 0), double(arguments, 1))
        case "dg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64) -> UInt64).self)
            return function(object, selector, double(arguments, 0), general(arguments, 1))
        case "dd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double) -> UInt64).self)
            return function(object, selector, double(arguments, 0), double(arguments, 1))
        case "ggg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64, UInt64) -> UInt64).self)
            return function(object, selector, general(arguments, 0), general(arguments, 1), general(arguments, 2))
        case "ggd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64, Double) -> UInt64).self)
            return function(object, selector, general(arguments, 0), general(arguments, 1), double(arguments, 2))
        case "gdg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double, UInt64) -> UInt64).self)
            return function(object, selector, general(arguments, 0), double(arguments, 1), general(arguments, 2))
        case "gdd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double, Double) -> UInt64).self)
            return function(object, selector, general(arguments, 0), double(arguments, 1), double(arguments, 2))
        case "dgg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64, UInt64) -> UInt64).self)
            return function(object, selector, double(arguments, 0), general(arguments, 1), general(arguments, 2))
        case "dgd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64, Double) -> UInt64).self)
            return function(object, selector, double(arguments, 0), general(arguments, 1), double(arguments, 2))
        case "ddg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double, UInt64) -> UInt64).self)
            return function(object, selector, double(arguments, 0), double(arguments, 1), general(arguments, 2))
        case "ddd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double, Double) -> UInt64).self)
            return function(object, selector, double(arguments, 0), double(arguments, 1), double(arguments, 2))
        default:
            throw RuntimeInvocationError.unsupportedArgumentCount(arguments.count)
        }
    }

    static func invokeFloatReturn(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws -> Float {
        switch try pattern(for: arguments) {
        case "":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector) -> Float).self)
            return function(object, selector)
        case "g":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64) -> Float).self)
            return function(object, selector, general(arguments, 0))
        case "d":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double) -> Float).self)
            return function(object, selector, double(arguments, 0))
        case "gg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64) -> Float).self)
            return function(object, selector, general(arguments, 0), general(arguments, 1))
        case "gd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double) -> Float).self)
            return function(object, selector, general(arguments, 0), double(arguments, 1))
        case "dg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64) -> Float).self)
            return function(object, selector, double(arguments, 0), general(arguments, 1))
        case "dd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double) -> Float).self)
            return function(object, selector, double(arguments, 0), double(arguments, 1))
        case "ggg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64, UInt64) -> Float).self)
            return function(object, selector, general(arguments, 0), general(arguments, 1), general(arguments, 2))
        case "ggd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64, Double) -> Float).self)
            return function(object, selector, general(arguments, 0), general(arguments, 1), double(arguments, 2))
        case "gdg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double, UInt64) -> Float).self)
            return function(object, selector, general(arguments, 0), double(arguments, 1), general(arguments, 2))
        case "gdd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double, Double) -> Float).self)
            return function(object, selector, general(arguments, 0), double(arguments, 1), double(arguments, 2))
        case "dgg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64, UInt64) -> Float).self)
            return function(object, selector, double(arguments, 0), general(arguments, 1), general(arguments, 2))
        case "dgd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64, Double) -> Float).self)
            return function(object, selector, double(arguments, 0), general(arguments, 1), double(arguments, 2))
        case "ddg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double, UInt64) -> Float).self)
            return function(object, selector, double(arguments, 0), double(arguments, 1), general(arguments, 2))
        case "ddd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double, Double) -> Float).self)
            return function(object, selector, double(arguments, 0), double(arguments, 1), double(arguments, 2))
        default:
            throw RuntimeInvocationError.unsupportedArgumentCount(arguments.count)
        }
    }

    static func invokeDoubleReturn(
        on object: AnyObject,
        selector: Selector,
        arguments: [PreparedInvocationArgument]
    ) throws -> Double {
        switch try pattern(for: arguments) {
        case "":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector) -> Double).self)
            return function(object, selector)
        case "g":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64) -> Double).self)
            return function(object, selector, general(arguments, 0))
        case "d":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double) -> Double).self)
            return function(object, selector, double(arguments, 0))
        case "gg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64) -> Double).self)
            return function(object, selector, general(arguments, 0), general(arguments, 1))
        case "gd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double) -> Double).self)
            return function(object, selector, general(arguments, 0), double(arguments, 1))
        case "dg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64) -> Double).self)
            return function(object, selector, double(arguments, 0), general(arguments, 1))
        case "dd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double) -> Double).self)
            return function(object, selector, double(arguments, 0), double(arguments, 1))
        case "ggg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64, UInt64) -> Double).self)
            return function(object, selector, general(arguments, 0), general(arguments, 1), general(arguments, 2))
        case "ggd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, UInt64, Double) -> Double).self)
            return function(object, selector, general(arguments, 0), general(arguments, 1), double(arguments, 2))
        case "gdg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double, UInt64) -> Double).self)
            return function(object, selector, general(arguments, 0), double(arguments, 1), general(arguments, 2))
        case "gdd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, UInt64, Double, Double) -> Double).self)
            return function(object, selector, general(arguments, 0), double(arguments, 1), double(arguments, 2))
        case "dgg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64, UInt64) -> Double).self)
            return function(object, selector, double(arguments, 0), general(arguments, 1), general(arguments, 2))
        case "dgd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, UInt64, Double) -> Double).self)
            return function(object, selector, double(arguments, 0), general(arguments, 1), double(arguments, 2))
        case "ddg":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double, UInt64) -> Double).self)
            return function(object, selector, double(arguments, 0), double(arguments, 1), general(arguments, 2))
        case "ddd":
            let function = unsafeBitCast(objcMessageSendPointer, to: (@convention(c) (AnyObject, Selector, Double, Double, Double) -> Double).self)
            return function(object, selector, double(arguments, 0), double(arguments, 1), double(arguments, 2))
        default:
            throw RuntimeInvocationError.unsupportedArgumentCount(arguments.count)
        }
    }

}
