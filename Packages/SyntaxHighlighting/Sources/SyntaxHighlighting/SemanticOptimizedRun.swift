//
//  SemanticOptimizedRun.swift
//  SyntaxHighlighting

import SwiftUI
import ClassDumpRuntime

public struct SemanticOptimizedRun: Identifiable {
    public let id: Int
    public let type: SemanticOptimizedType
    
    @MainActor
    public static func optimize(lineContent: [SemanticRun], colors: Theme) -> [Self] {
        var ret: [Self] = []
        
        var currentText: Text?
        var currentLength: Int = 0
        
        func pushRun() {
            if let prefix = currentText {
                ret.append(.init(id: ret.count, type: .text(prefix)))
                currentText = nil
                currentLength = 0
            }
        }
        
        for content in lineContent {
            func pushText(_ provider: (Text) -> Text) {
                let str = content.string
                let text = provider(Text(str))
                
                if let prefix = currentText {
                    currentText = prefix + text
                } else {
                    currentText = text
                }
                
                currentLength += str.count
                // optimization tuning parameter:
                // too low -> laying out each line may take a long time
                // too high -> Text may fail to layout
                if currentLength > 512 {
                    pushRun()
                }
            }
            
            func pushSemanticLink(type: CDSemanticType, _ provider: (Text) -> Text) {
                pushRun()
                let text = provider(
                    Text(content.string)
                )

                ret.append(
                    .init(id: ret.count, type: .semanticLink(type: type, string: content.string, text))
                )
            }
             
            switch content.type {
            case .standard:
                pushText {
                    $0.foregroundColor(colors.standard)
                }
            case .comment:
                pushText {
                    $0.foregroundColor(colors.comment)
                }
            case .keyword:
                pushText {
                    $0.foregroundColor(colors.keyword)
                }
            case .variable:
                pushText {
                    $0.foregroundColor(colors.variable)
                }
            case .recordName:
                pushText {
                    $0.foregroundColor(colors.recordName)
                }
            case .class:
                pushSemanticLink(type: content.type) {
                    $0.foregroundColor(colors.class)
                }
            case .protocol:
                pushSemanticLink(type: content.type) {
                    $0.foregroundColor(colors.protocol)
                }
            case .numeric:
                pushText {
                    $0.foregroundColor(colors.number)
                }
            default:
                pushText {
                    $0.foregroundColor(colors.defaultValue)
                }
            }
        }
        
        pushRun()
        
        return ret
    }
}
