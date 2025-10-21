//
//  CodeEditorPreferences.swift
//  HeaderViewer
    

import SwiftUI


class CodePreferences: ObservableObject {
    static let shared = CodePreferences()
    
    @Published var colors: SemanticColor = SemanticColor()
    @AppStorage("selectedTheme") var selectedTheme: String = "system" // the default theme the app provided
    @AppStorage("hideLineNumbers") var hideLineNumbers: Bool = true
    
    
    @AppStorage("fontSize") var fontSize: Int = 16
    @AppStorage("fontName") var fontName: String = "SFMono-Regular"

    let minFontSize: Int = 8
    let maxFontSize: Int = 24
    
    
    func apply(_ theme: Theme) {
        self.colors.standard = theme.standard
        self.colors.comment = theme.comment
        self.colors.keyword = theme.keyword
        self.colors.variable = theme.variable
        self.colors.number = theme.number
        self.colors.recordName = theme.recordName
        self.colors.class = theme.class
        self.colors.protocol = theme.protocol
        self.colors.defaultValue = theme.defaultValue
        
        selectedTheme = theme.name
        print("new theme applied: \(selectedTheme)")
    }
    
    func toggleThemeBasedOnColorScheme(_ newScheme: ColorScheme) {
        let theme = selectedTheme.lowercased()
        if theme == "system" { return }
        
        if newScheme == .dark {
            if theme.contains("xcode") { return apply(.xcodeDark) }
            if theme.contains("github") { return apply(.githubDark) }
            if theme.contains("solarized") { return apply(.solarizedDark) }
        } else {
            if theme.contains("xcode") { return apply(.xcodeLight) }
            if theme.contains("github") { return apply(.githubLight) }
            if theme.contains("solarized") { return apply(.solarizedLight) }
        }
    }
    
    var swiftUIFont: Font {
        Font(
            UIFont(name: fontName,size: CGFloat(fontSize)) ??
            .monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        )
    }
}
