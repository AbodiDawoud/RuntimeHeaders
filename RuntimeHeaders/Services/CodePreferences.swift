//
//  CodePreferences.swift
//  RuntimeHeaders
    

import SwiftUI
import ClassDumpRuntime
import SyntaxHighlighting


@MainActor
final class CodePreferences: ObservableObject {
    static let shared = CodePreferences()

    @Published var colors: Theme {
        didSet {
            persist(colors)
        }
    }

    @AppStorage("selectedTheme") var selectedTheme: String = "system"
    @AppStorage("hideLineNumbers") var hideLineNumbers: Bool = true
    @AppStorage("fontSize") var fontSize: Int = 16
    @AppStorage("fontName") var fontName: String = "SFMono-Regular"

    private static let defaultColorKey = "default_color"
    let minFontSize: Int = 8
    let maxFontSize: Int = 24

    
    private init() {
        colors = Self.restoredTheme()
    }

    func apply(_ theme: Theme) {
        colors.standard = theme.standard
        colors.comment = theme.comment
        colors.keyword = theme.keyword
        colors.variable = theme.variable
        colors.number = theme.number
        colors.recordName = theme.recordName
        colors.class = theme.class
        colors.protocol = theme.protocol
        colors.defaultValue = theme.defaultValue

        selectedTheme = theme.name
    }

    func toggleThemeBasedOnColorScheme(_ newScheme: ColorScheme) {
        let theme = selectedTheme.lowercased()
        if theme == "system" { return }

        if newScheme == .dark {
            if theme.contains("xcode") { return apply(.xcodeDark) }
            if theme.contains("classic") { return apply(.classicDark) }
            if theme.contains("github") { return apply(.githubDark) }
            if theme.contains("solarized") { return apply(.solarizedDark) }
        } else {
            if theme.contains("xcode") { return apply(.xcodeLight) }
            if theme.contains("classic") { return apply(.classicLight) }
            if theme.contains("github") { return apply(.githubLight) }
            if theme.contains("solarized") { return apply(.solarizedLight) }
        }
    }

    var swiftUIFont: Font {
        Font(
            UIFont(name: fontName, size: CGFloat(fontSize)) ??
            .monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        )
    }

    private static func restoredTheme() -> Theme {
        Theme(
            name: UserDefaults.standard.string(forKey: "theme_name") ?? "System",
            standard: restoredColor(for: CDSemanticType.standard.key, fallback: Theme.system.standard),
            comment: restoredColor(for: CDSemanticType.comment.key, fallback: Theme.system.comment),
            keyword: restoredColor(for: CDSemanticType.keyword.key, fallback: Theme.system.keyword),
            variable: restoredColor(for: CDSemanticType.variable.key, fallback: Theme.system.variable),
            number: restoredColor(for: CDSemanticType.numeric.key, fallback: Theme.system.number),
            recordName: restoredColor(for: CDSemanticType.recordName.key, fallback: Theme.system.recordName),
            class: restoredColor(for: CDSemanticType.class.key, fallback: Theme.system.class),
            protocol: restoredColor(for: CDSemanticType.protocol.key, fallback: Theme.system.protocol),
            defaultValue: restoredColor(for: Self.defaultColorKey, fallback: Theme.system.defaultValue)
        )
    }

    private static func restoredColor(for key: String, fallback: Color) -> Color {
        guard let hexValue = UserDefaults.standard.string(forKey: key) else { return fallback }
        return Color(hex: hexValue)
    }

    private func persist(_ theme: Theme) {
        UserDefaults.standard.set(theme.name, forKey: "theme_name")
        persist(theme.standard, for: CDSemanticType.standard.key)
        persist(theme.comment, for: CDSemanticType.comment.key)
        persist(theme.keyword, for: CDSemanticType.keyword.key)
        persist(theme.variable, for: CDSemanticType.variable.key)
        persist(theme.number, for: CDSemanticType.numeric.key)
        persist(theme.recordName, for: CDSemanticType.recordName.key)
        persist(theme.class, for: CDSemanticType.class.key)
        persist(theme.protocol, for: CDSemanticType.protocol.key)
        persist(theme.defaultValue, for: Self.defaultColorKey)
    }

    private func persist(_ color: Color, for key: String) {
        UserDefaults.standard.set(color.toHex(), forKey: key)
    }
}

private extension CDSemanticType {
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
