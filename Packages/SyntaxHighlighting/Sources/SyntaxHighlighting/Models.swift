//
//  Models.swift
//  SyntaxHighlighting
    

import SwiftUI
import ClassDumpRuntime


public struct SemanticLine: Identifiable {
    public let number: Int
    public let content: [SemanticRun]
    
    public var id: Int { number }
    
    public init(number: Int, content: [SemanticRun]) {
        self.number = number
        self.content = content
    }
}


public struct SemanticRun: Identifiable {
    public let id: Int  // it is the caller's responsibility to set a unique id relative to the container
    public let string: String
    public let type: CDSemanticType
    
    public init(id: Int, string: String, type: CDSemanticType) {
        self.id = id
        self.string = string
        self.type = type
    }
}


public enum SemanticOptimizedType {
    case text(Text)
    case semanticLink(type: CDSemanticType, string: String, Text)
}
