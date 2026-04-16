//
//  NamedNodeExporter.swift
//  RuntimeHeaders

import UIKit
import ClassDumpRuntime
import ObjectiveC
import SyntaxHighlighting


final class NamedNodeExporter {
    private let listings: RuntimeListings
    private let fileManager = FileManager.default
    
    init(listings: RuntimeListings = .shared) {
        self.listings = listings
    }
    
    func exportHeaders(for node: NamedNode) throws -> URL {
        let imageNodes = leafNodes(in: node)
        guard imageNodes.isEmpty == false else {
            throw ExportError.noImages
        }
        
        let folderName = "\(safeFileName(node.name, fallback: "RuntimeHeaders"))-Headers-\(UUID().uuidString)"
        let folderURL = fileManager.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        var exportedHeaderCount = 0
        
        for imageNode in imageNodes {
            let destinationFolder = try destinationFolder(for: imageNode, in: folderURL, splitByImage: imageNodes.count > 1)
            exportedHeaderCount += try exportHeaders(from: imageNode, to: destinationFolder)
        }
        
        guard exportedHeaderCount > 0 else {
            throw ExportError.noHeaders(node.name)
        }
        
        return folderURL
    }
    
    private func destinationFolder(for imageNode: NamedNode, in folderURL: URL, splitByImage: Bool) throws -> URL {
        guard splitByImage else { return folderURL  }
        
        let destinationFolder = folderURL.appendingPathComponent(
            safeFileName(imageNode.name, fallback: "Image"),
            isDirectory: true
        )
        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        return destinationFolder
    }
    
    private func leafNodes(in node: NamedNode) -> [NamedNode] {
        if node.isLeaf {
            return [node]
        }
        
        return node.children.flatMap(leafNodes)
    }
    
    private func exportHeaders(from imageNode: NamedNode, to folder: URL) throws -> Int {
        let imagePath = imageNode.path
        
        if listings.isImageLoaded(path: imagePath) == false {
            try CDUtilities.loadImage(at: imagePath)
        }
        
        let classNames = CDUtilities.classNamesIn(image: imagePath).sorted()
        let protocolNames = protocolNames(in: imagePath).sorted()
        let runtimeObjects = classNames.map { RuntimeObjectType.class(named: $0) }
            + protocolNames.map { RuntimeObjectType.protocol(named: $0) }
        
        var usedFileNames: Set<String> = []
        var exportedHeaderCount = 0
        
        for runtimeObject in runtimeObjects {
            guard let content = headerContent(for: runtimeObject) else { continue }
            
            let fileURL = uniqueHeaderURL(for: runtimeObject, in: folder, usedFileNames: &usedFileNames)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedHeaderCount += 1
        }
        
        return exportedHeaderCount
    }
    
    private func protocolNames(in imagePath: String) -> [String] {
        let patchedImagePath = CDUtilities.patchImagePathForDyld(imagePath)
        let cachedNames = listings.imageToProtocols[patchedImagePath] ?? []
        
        if cachedNames.isEmpty == false {
            return cachedNames
        }
        
        return CDUtilities.protocolNames().filter { protocolName in
            guard let prtcl = NSProtocolFromString(protocolName) else { return false }
            
            var dlInfo = dl_info()
            guard dladdr(protocol_getName(prtcl), &dlInfo) != 0,
                  let imageName = dlInfo.dli_fname else {
                return false
            }
            
            return String(cString: imageName) == patchedImagePath
        }
    }
    
    private func headerContent(for runtimeObject: RuntimeObjectType) -> String? {
        let semanticString: CDSemanticString
        
        switch runtimeObject {
        case .class(let name):
            guard let cls = NSClassFromString(name) else { return nil }
            semanticString = CDClassModel(with: cls).semanticLines(with: defaultGenerationOptions)
            
        case .protocol(let name):
            guard let prtcl = NSProtocolFromString(name) else { return nil }
            semanticString = CDProtocolModel(with: prtcl).semanticLines(with: defaultGenerationOptions)
        }
        
        return plainText(from: semanticString)
    }
    
    private var defaultGenerationOptions: CDGenerationOptions {
        let options: CDGenerationOptions = .init()
        options.stripProtocolConformance = false
        options.stripOverrides = false
        options.stripDuplicates = true
        options.stripSynthesized = true
        options.stripCtorMethod = true
        options.stripDtorMethod = true
        options.addSymbolImageComments = false
        return options
    }
    
    private func plainText(from semanticString: CDSemanticString) -> String {
        semanticLinesFromString(semanticString).lines
            .map { line in
                line.content.map(\.string).joined()
            }
            .joined(separator: "\n")
    }
    
    private func uniqueHeaderURL(
        for runtimeObject: RuntimeObjectType,
        in folder: URL,
        usedFileNames: inout Set<String>
    ) -> URL {
        let baseName = safeFileName(runtimeObject.name, fallback: "Header")
        var fileName = "\(baseName).h"
        
        if usedFileNames.contains(fileName) {
            switch runtimeObject {
            case .class:
                fileName = "\(baseName)-Class.h"
            case .protocol:
                fileName = "\(baseName)-Protocol.h"
            }
        }
        
        var candidateName = fileName
        var duplicateIndex = 2
        
        while usedFileNames.contains(candidateName) {
            let base = fileName.dropLast(2)
            candidateName = "\(base)-\(duplicateIndex).h"
            duplicateIndex += 1
        }
        
        usedFileNames.insert(candidateName)
        return folder.appendingPathComponent(candidateName)
    }
    
    private func safeFileName(_ rawName: String, fallback: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let pieces = rawName.components(separatedBy: invalidCharacters)
        let fileName = pieces.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return fileName.isEmpty ? fallback : fileName
    }
}

extension NamedNodeExporter {
    enum ExportError: LocalizedError {
        case noImages
        case noHeaders(String)
        
        var errorDescription: String? {
            switch self {
            case .noImages:
                return "No framework images were found inside the selected node."
            case .noHeaders(let name):
                return "No classes or protocols were found in \(name)."
            }
        }
    }
}
