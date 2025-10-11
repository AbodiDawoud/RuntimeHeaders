//
//  SemanticColor.swift
//  HeaderViewer
    

import SwiftUI
import ClassDumpRuntime


struct SemanticColor {
    @ThemedColor(Theme.system.standard, key: CDSemanticType.standard.key)
    var standard: Color
    
    
    @ThemedColor(Theme.system.comment, key: CDSemanticType.comment.key)
    var comment: Color
    
    
    @ThemedColor(Theme.system.keyword, key: CDSemanticType.keyword.key)
    var keyword: Color
    
    
    @ThemedColor(Theme.system.variable, key: CDSemanticType.variable.key)
    var variable: Color
    
    
    @ThemedColor(Theme.system.number, key: CDSemanticType.numeric.key)
    var number: Color
    
    
    @ThemedColor(Theme.system.recordName, key: CDSemanticType.recordName.key)
    var recordName: Color
    
    
    @ThemedColor(Theme.system.class, key: CDSemanticType.class.key)
    var `class`: Color
    
    
    @ThemedColor(Theme.system.protocol, key: CDSemanticType.protocol.key)
    var `protocol`: Color
    
    
    // The "SemanticOptimizedRun" class is switching on a "default" value, we have to provide a color for it.
    @ThemedColor(Theme.system.defaultValue, key: "default_color")
    var defaultValue: Color
}



private extension CDSemanticType {
    /// The key to be stored in `UserDefaults`
    var key: String {
        switch self {
        case .standard: return "standard_color"
        case .comment: return "comment_color"
        case .keyword: return "keyword_color"
        case .variable: return "variable_color"
        case .numeric: return "numeric_color"
        case .recordName: return "record_name_color"
        case .class: return "class_color"
        case .protocol: return "protocol_color"
        
        default: return ""
        }
    }
}


@propertyWrapper
struct ThemedColor {
    private let defaultValue: Color
    private let key: String

    init(_ defaultValue: Color, key: String) {
        self.defaultValue = defaultValue
        self.key = key
    }

    var wrappedValue: Color {
        get {
            guard let hexValue = UserDefaults.standard.string(forKey: key)
            else { return defaultValue }
            
            return Color(hex: hexValue)
        }
        set {
            UserDefaults.standard.set(newValue.toHex(), forKey: key)
        }
    }
}
