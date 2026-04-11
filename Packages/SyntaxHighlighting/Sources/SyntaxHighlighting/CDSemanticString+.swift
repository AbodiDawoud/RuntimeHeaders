//
//  CDSemanticString+.swift
//  SyntaxHighlighting
    

import Foundation
import ClassDumpRuntime


public func semanticLinesFromString(_ input: CDSemanticString) -> (lines: [SemanticLine], longestLineIndex: Int?) {
    var lines: [SemanticLine] = []
    var longestLineIndex: Int?
    var longestLineLength: Int = 0
    
    var current: [SemanticRun] = []
    var currentLineLength = 0
    
    func pushLine() {
        let upcomingIndex = lines.count
        lines.append(SemanticLine(number: upcomingIndex, content: current))
        if currentLineLength > longestLineLength {
            longestLineLength = currentLineLength
            longestLineIndex = upcomingIndex
        }
        current = []
        currentLineLength = 0
    }
    
    input.enumerateTypes { str, type in
        func pushRun(string: String) {
            current.append(SemanticRun(id: current.count, string: string, type: type))
            currentLineLength += string.count
        }
        
        var movingSubstring: String = str
        while let lineBreakIndex = movingSubstring.firstIndex(of: "\n") {
            pushRun(string: String(movingSubstring[..<lineBreakIndex]))
            pushLine()
            // index after because we don't want to include '\n' in the output
            movingSubstring = String(movingSubstring[movingSubstring.index(after: lineBreakIndex)...])
        }
        pushRun(string: movingSubstring)
    }
    if !current.isEmpty {
        pushLine()
    }
    return (lines, longestLineIndex)
}
