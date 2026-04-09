//
//  RuntimeInvocationEngine.swift
//  RuntimeHeaders
//

import Foundation
import Darwin
import ObjectiveC.runtime

enum RuntimeInvocationError: LocalizedError {
    case missingMethod(String)
    case unsupportedReturnType(String)
    case nilObjectReturn(String)

    var errorDescription: String? {
        switch self {
        case .missingMethod(let selectorName):
            "Missing method '\(selectorName)'."
        case .unsupportedReturnType(let encoding):
            "Unsupported return type '\(encoding)'."
        case .nilObjectReturn(let selectorName):
            "'\(selectorName)' returned nil."
        }
    }
}

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

    static func invokeInstanceMethod(
        on object: AnyObject,
        selector: Selector,
        returnTypeEncoding: String
    ) throws -> String {
        let methodName = NSStringFromSelector(selector)
        switch returnKind(for: returnTypeEncoding) {
        case .void:
            typealias Function = @convention(c) (AnyObject, Selector) -> Void
            let function = unsafeBitCast(objcMessageSendPointer, to: Function.self)
            function(object, selector)
            return "Completed"

        case .object:
            typealias Function = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
            let function = unsafeBitCast(objcMessageSendPointer, to: Function.self)
            guard let result = function(object, selector)?.takeUnretainedValue() else {
                throw RuntimeInvocationError.nilObjectReturn(methodName)
            }
            return describe(value: result)

        case .bool:
            typealias Function = @convention(c) (AnyObject, Selector) -> Bool
            let function = unsafeBitCast(objcMessageSendPointer, to: Function.self)
            return function(object, selector) ? "true" : "false"

        case .integer:
            typealias Function = @convention(c) (AnyObject, Selector) -> Int
            let function = unsafeBitCast(objcMessageSendPointer, to: Function.self)
            return String(function(object, selector))

        case .unsignedInteger:
            typealias Function = @convention(c) (AnyObject, Selector) -> UInt
            let function = unsafeBitCast(objcMessageSendPointer, to: Function.self)
            return String(function(object, selector))

        case .floatingPoint:
            if returnTypeEncoding == "f" {
                typealias Function = @convention(c) (AnyObject, Selector) -> Float
                let function = unsafeBitCast(objcMessageSendPointer, to: Function.self)
                return String(function(object, selector))
            } else {
                typealias Function = @convention(c) (AnyObject, Selector) -> Double
                let function = unsafeBitCast(objcMessageSendPointer, to: Function.self)
                return String(function(object, selector))
            }

        case .unsupported:
            throw RuntimeInvocationError.unsupportedReturnType(returnTypeEncoding)
        }
    }

    static func returnKind(for encoding: String) -> InspectableMethodReturnKind {
        switch encoding.first {
        case "v":
            .void
        case "@":
            .object
        case "B":
            .bool
        case "q", "i", "s", "l":
            .integer
        case "Q", "I", "S", "L":
            .unsignedInteger
        case "d", "f":
            .floatingPoint
        default:
            .unsupported
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
