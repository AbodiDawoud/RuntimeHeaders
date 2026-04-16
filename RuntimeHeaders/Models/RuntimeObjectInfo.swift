//
//  RuntimeObjectInfo.swift
//  RuntimeHeaders
    

import Foundation

struct RuntimeObjectInfo {
    let title: String
    let kind: String
    let parentFramework: String?
    let path: String?
    let totalLines: Int
    let totalProperties: Int?
    let totalInstanceMethods: Int?
    let totalClassMethods: Int?
    let totalMethods: Int?
    let ivarCount: Int?
    let instanceSize: Int?
    let inheritance: [String]
    let adoptedProtocols: [String]
    let inheritedProtocols: [String]
    let requiredInstanceMethods: Int?
    let optionalInstanceMethods: Int?
    let requiredClassMethods: Int?
    let optionalClassMethods: Int?

    init(type: RuntimeObjectType?, fileName: String, frameworkPath: String?, lineCount: Int) {
        switch type {
        case .class(let name):
            self = Self.classInfo(named: name, fallbackName: fileName, frameworkPath: frameworkPath, lineCount: lineCount)
        case .protocol(let name):
            self = Self.protocolInfo(named: name, fallbackName: fileName, frameworkPath: frameworkPath, lineCount: lineCount)
        case nil:
            self.title = fileName
            self.kind = "Header"
            self.parentFramework = Self.frameworkName(from: frameworkPath)
            self.path = frameworkPath
            self.totalLines = lineCount
            self.totalProperties = nil
            self.totalInstanceMethods = nil
            self.totalClassMethods = nil
            self.totalMethods = nil
            self.ivarCount = nil
            self.instanceSize = nil
            self.inheritance = []
            self.adoptedProtocols = []
            self.inheritedProtocols = []
            self.requiredInstanceMethods = nil
            self.optionalInstanceMethods = nil
            self.requiredClassMethods = nil
            self.optionalClassMethods = nil
        }
    }

    private init(
        title: String,
        kind: String,
        parentFramework: String?,
        path: String?,
        totalLines: Int,
        totalProperties: Int?,
        totalInstanceMethods: Int?,
        totalClassMethods: Int?,
        totalMethods: Int?,
        ivarCount: Int?,
        instanceSize: Int?,
        inheritance: [String],
        adoptedProtocols: [String],
        inheritedProtocols: [String],
        requiredInstanceMethods: Int?,
        optionalInstanceMethods: Int?,
        requiredClassMethods: Int?,
        optionalClassMethods: Int?
    ) {
        self.title = title
        self.kind = kind
        self.parentFramework = parentFramework
        self.path = path
        self.totalLines = totalLines
        self.totalProperties = totalProperties
        self.totalInstanceMethods = totalInstanceMethods
        self.totalClassMethods = totalClassMethods
        self.totalMethods = totalMethods
        self.ivarCount = ivarCount
        self.instanceSize = instanceSize
        self.inheritance = inheritance
        self.adoptedProtocols = adoptedProtocols
        self.inheritedProtocols = inheritedProtocols
        self.requiredInstanceMethods = requiredInstanceMethods
        self.optionalInstanceMethods = optionalInstanceMethods
        self.requiredClassMethods = requiredClassMethods
        self.optionalClassMethods = optionalClassMethods
    }

    private static func classInfo(named name: String, fallbackName: String, frameworkPath: String?, lineCount: Int) -> RuntimeObjectInfo {
        guard let cls = NSClassFromString(name) else {
            return missingInfo(kind: "Class", fallbackName: fallbackName, frameworkPath: frameworkPath, lineCount: lineCount)
        }

        let imagePath = frameworkPath ?? imagePath(for: class_getName(cls))
        let instanceMethods = countCopiedList { class_copyMethodList(cls, $0) }
        let classMethods = countCopiedList { class_copyMethodList(object_getClass(cls), $0) }
        let properties = countCopiedList { class_copyPropertyList(cls, $0) }
        let ivars = countCopiedList { class_copyIvarList(cls, $0) }
        let protocols = protocolNames(forClass: cls)

        return RuntimeObjectInfo(
            title: fallbackName,
            kind: "Class",
            parentFramework: frameworkName(from: imagePath),
            path: imagePath,
            totalLines: lineCount,
            totalProperties: properties,
            totalInstanceMethods: instanceMethods,
            totalClassMethods: classMethods,
            totalMethods: instanceMethods + classMethods,
            ivarCount: ivars,
            instanceSize: class_getInstanceSize(cls),
            inheritance: inheritanceChain(for: cls),
            adoptedProtocols: protocols,
            inheritedProtocols: [],
            requiredInstanceMethods: nil,
            optionalInstanceMethods: nil,
            requiredClassMethods: nil,
            optionalClassMethods: nil
        )
    }

    private static func protocolInfo(named name: String, fallbackName: String, frameworkPath: String?, lineCount: Int) -> RuntimeObjectInfo {
        guard let prtcl = NSProtocolFromString(name) else {
            return missingInfo(kind: "Protocol", fallbackName: fallbackName, frameworkPath: frameworkPath, lineCount: lineCount)
        }

        let imagePath = frameworkPath ?? imagePath(for: protocol_getName(prtcl))
        let requiredInstanceMethods = countCopiedList {
            protocol_copyMethodDescriptionList(prtcl, true, true, $0)
        }
        let optionalInstanceMethods = countCopiedList {
            protocol_copyMethodDescriptionList(prtcl, false, true, $0)
        }
        let requiredClassMethods = countCopiedList {
            protocol_copyMethodDescriptionList(prtcl, true, false, $0)
        }
        let optionalClassMethods = countCopiedList {
            protocol_copyMethodDescriptionList(prtcl, false, false, $0)
        }

        let totalMethods = requiredInstanceMethods + optionalInstanceMethods + requiredClassMethods + optionalClassMethods

        return RuntimeObjectInfo(
            title: fallbackName,
            kind: "Protocol",
            parentFramework: frameworkName(from: imagePath),
            path: imagePath,
            totalLines: lineCount,
            totalProperties: countCopiedList { protocol_copyPropertyList(prtcl, $0) },
            totalInstanceMethods: requiredInstanceMethods + optionalInstanceMethods,
            totalClassMethods: requiredClassMethods + optionalClassMethods,
            totalMethods: totalMethods,
            ivarCount: nil,
            instanceSize: nil,
            inheritance: [],
            adoptedProtocols: [],
            inheritedProtocols: inheritedProtocolNames(for: prtcl),
            requiredInstanceMethods: requiredInstanceMethods,
            optionalInstanceMethods: optionalInstanceMethods,
            requiredClassMethods: requiredClassMethods,
            optionalClassMethods: optionalClassMethods
        )
    }

    private static func missingInfo(kind: String, fallbackName: String, frameworkPath: String?, lineCount: Int) -> RuntimeObjectInfo {
        RuntimeObjectInfo(
            title: fallbackName,
            kind: kind,
            parentFramework: frameworkName(from: frameworkPath),
            path: frameworkPath,
            totalLines: lineCount,
            totalProperties: nil,
            totalInstanceMethods: nil,
            totalClassMethods: nil,
            totalMethods: nil,
            ivarCount: nil,
            instanceSize: nil,
            inheritance: [],
            adoptedProtocols: [],
            inheritedProtocols: [],
            requiredInstanceMethods: nil,
            optionalInstanceMethods: nil,
            requiredClassMethods: nil,
            optionalClassMethods: nil
        )
    }

    private static func countCopiedList<Element>(_ copyList: (UnsafeMutablePointer<UInt32>) -> UnsafeMutablePointer<Element>?) -> Int {
        var count: UInt32 = 0
        let list = copyList(&count)
        list?.deallocate()
        return Int(count)
    }

    private static func inheritanceChain(for cls: AnyClass) -> [String] {
        var classes: [String] = []
        var current: AnyClass? = cls

        while let currentClass = current {
            classes.append(String(cString: class_getName(currentClass)))
            current = class_getSuperclass(currentClass)
        }

        return classes
    }

    private static func protocolNames(forClass cls: AnyClass) -> [String] {
        var count: UInt32 = 0
        guard let list = class_copyProtocolList(cls, &count) else { return [] }

        return (0..<Int(count))
            .map { NSStringFromProtocol(list[$0]) }
            .sorted()
    }

    private static func inheritedProtocolNames(for prtcl: Protocol) -> [String] {
        var count: UInt32 = 0
        guard let list = protocol_copyProtocolList(prtcl, &count) else { return [] }

        return (0..<Int(count))
            .map { NSStringFromProtocol(list[$0]) }
            .sorted()
    }

    private static func imagePath(for cString: UnsafePointer<CChar>) -> String? {
        var dlInfo = dl_info()
        guard dladdr(cString, &dlInfo) != 0,
              let imageName = dlInfo.dli_fname else {
            return nil
        }

        return String(cString: imageName)
    }

    private static func frameworkName(from path: String?) -> String? {
        guard let path, path.isEmpty == false else { return nil }
        let components = path.split(separator: "/").map(String.init)

        if let framework = components.last(where: { $0.hasSuffix(".framework") }) {
            return String(framework.dropLast(".framework".count))
        }

        return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}
