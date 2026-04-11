//
//  CodeAppearanceView.swift
//  HeaderViewer
    

import SwiftUI
import SyntaxHighlighting


struct CodeAppearanceView: View {
    @ObservedObject private var preferences = CodePreferences.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            Form {
                CodePreview()
                
                FontCustomization()
                
                ThemesContainerView()
                
                Section("Standard") {
                    colorPickerRow("Default", color: $preferences.colors.standard, icon: "circle.dashed", colorStyle: .gray)
                    colorPickerRow("Comment", color: $preferences.colors.comment, icon: "text.bubble", colorStyle: .indigo)
                    colorPickerRow("Keyword", color: $preferences.colors.keyword, icon: "key.fill", colorStyle: .pink)
                }
                
                Section("Identifiers") {
                    colorPickerRow("Variable", color: $preferences.colors.variable, icon: "v.square.fill", colorStyle: .teal)
                    colorPickerRow("Record", color: $preferences.colors.recordName, icon: "r.square.fill", colorStyle: .aqua)
                }
                .imageScale(.large)
                
                Section("Types") {
                    colorPickerRow("Class", color: $preferences.colors.class, icon: "c.square.fill", colorStyle: .spring)
                    colorPickerRow("Protocol", color: $preferences.colors.protocol, icon: "p.square.fill", colorStyle: .plum)
                }
                .imageScale(.large)
                
                Section {
                    colorPickerRow("Number", color: $preferences.colors.number, icon: "number", colorStyle: .orange)
                    colorPickerRow("Fallback", color: $preferences.colors.defaultValue, icon: "circle.fill", colorStyle: .black)
                } header: {
                    Text("Literals")
                } footer: {
                    Text("The fallback color is used in **very rare** cases where the word doesn't fit into any of the other categories.")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        dismissButton
                        
                        Text("Code Appearance")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) { resetButton }
            }
        }
    }
    
    private func colorPickerRow(_ label: String, color: Binding<Color>, icon: String, colorStyle: Color) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .labelStyle(IconicLabelStyle(colorStyle))
            
            Spacer()
            
            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
        }
    }
    
    private var dismissButton: some View {
        Button(action: dismiss.callAsFunction) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.gray)
                .bold()
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
    }
    
    private var resetButton: some View {
        Button(action: resetAppearance) {
            Text("Reset")
                .font(.system(.subheadline, design: .default, weight: .medium))
                .foregroundStyle(.gray.gradient)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .stroke(Color.pink.opacity(0.06), lineWidth: 0.9)
                        .fill(.gray.quinary.opacity(scheme == .light ? 0.4 : 0.95))
                )
        }
        .buttonStyle(.plain)
    }
    
    func resetAppearance() {
        preferences.apply(.system)
        preferences.fontSize = 16
        preferences.fontName = "SFMono-Regular"
        preferences.hideLineNumbers = true
    }
}

fileprivate struct FontCustomization: View {
    @ObservedObject var preferences = CodePreferences.shared
    
    var body: some View {
        Section("Font") {
            Stepper(value: $preferences.fontSize, in: fontSizeRange) {
                Label("Font Size: \(preferences.fontSize)", systemImage: "textformat.size")
            }
            
            Picker("Font", selection: $preferences.fontName) {
                ForEach(availableFonts, id: \.self) { name in
                    Text(name)
                        .font(Font.custom(name, size: 14))
                }
            }
            .pickerStyle(.navigationLink)
            .foregroundStyle(.primary, .blue)
        }
    }
    
    private var fontSizeRange: ClosedRange<Int> {
        return preferences.minFontSize...preferences.maxFontSize
    }
    
    private var availableFonts: [String] {
        [
            "SFMono-Regular",     // default
            "Menlo-Regular",
            "Courier New",
            "FiraCode-Regular",
            "JetBrainsMono-Regular",
            "Lilex-Regular",
            "ConsolasVD3-Regular"
        ].filter { UIFont(name: $0, size: 13) != nil }
    }
}



fileprivate struct CodePreview: View {
    @ObservedObject var preferences = CodePreferences.shared
    
    var body: some View {
        Section("Preview") {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(previewLines.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            if !preferences.hideLineNumbers {
                                Text("\(index)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            lineRow(previewLines[index])
                        }
                    }
                }
            }
            
            LabeledContent("Theme") {
                Text(preferences.selectedTheme)
            }
            
            Toggle("Hide Prefix Numbers", isOn: $preferences.hideLineNumbers)
        }
    }

    func lineRow(_ line: SemanticLine) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(SemanticOptimizedRun.optimize(lineContent: line.content, colors: preferences.colors)) {
                switch $0.type {
                case .text(let text): text
                case .semanticLink(_, _, let text): text
                }
            }
        }
        .font(preferences.swiftUIFont)
        .padding(.vertical, 1) // effectively line spacing
    }
    
    
    let previewLines: [SemanticLine] = [
        SemanticLine(number: 0, content: [
            SemanticRun(id: 0, string: "// Preview your code style", type: .comment)
        ]),
        SemanticLine(number: 1, content: [
            SemanticRun(id: 1, string: "class", type: .keyword),
            SemanticRun(id: 2, string: " ", type: .standard),
            SemanticRun(id: 3, string: "MyView", type: .class),
            SemanticRun(id: 4, string: ":", type: .standard),
            SemanticRun(id: 5, string: " ", type: .standard),
            SemanticRun(id: 6, string: "UIView", type: .protocol),
            SemanticRun(id: 06, string: " {", type: .standard),
        ]),
        SemanticLine(number: 2, content: [
            SemanticRun(id: 7, string: "    let", type: .keyword),
            SemanticRun(id: 8, string: " ", type: .standard),
            SemanticRun(id: 9, string: "title", type: .variable),
            SemanticRun(id: 10, string: " =", type: .standard),
            SemanticRun(id: 11, string: " ", type: .standard),
            SemanticRun(id: 12, string: "\"Hello\"", type: .recordName),
        ]),
        SemanticLine(number: 3, content: [
            SemanticRun(id: 13, string: "    let", type: .keyword),
            SemanticRun(id: 14, string: " ", type: .standard),
            SemanticRun(id: 15, string: "count", type: .variable),
            SemanticRun(id: 16, string: " =", type: .standard),
            SemanticRun(id: 17, string: " ", type: .standard),
            SemanticRun(id: 18, string: "42", type: .numeric),
        ]),
        SemanticLine(number: 4, content: [
            SemanticRun(id: 13, string: "}", type: .standard),
        ])
    ]
}



fileprivate struct ThemesContainerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var codePreferences = CodePreferences.shared
    
    var body: some View {
        Section("Themes") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(themeOptions) { option in
                        Button(option.title, systemImage: option.systemImage) {
                            codePreferences.apply(option.theme)
                        }
                        .buttonStyle(ThemeButtonStyle(option.tint))
                    }
                }
                .padding(.horizontal, 2)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private var themeOptions: [ThemeOption] {
        [
            ThemeOption(title: "Xcode", systemImage: "hammer.fill", theme: xcodeTheme, tint: darkTeal),
            ThemeOption(title: "Classic", systemImage: "macwindow", theme: classicTheme, tint: .mint),
            ThemeOption(title: "Github", systemImage: "chevron.left.forwardslash.chevron.right", theme: githubTheme, tint: darkPurple),
            ThemeOption(title: "Solarized", systemImage: "sun.max.fill", theme: solarizedTheme, tint: .strawberry),
            ThemeOption(title: "Civic", systemImage: "building.columns.fill", theme: .civic, tint: .teal),
            ThemeOption(title: "Dusk", systemImage: "sunset.fill", theme: .dusk, tint: .indigo),
            ThemeOption(title: "Midnight", systemImage: "moon.stars.fill", theme: .midnight, tint: .blue),
            ThemeOption(title: "Sunset", systemImage: "sun.horizon.fill", theme: .sunset, tint: .orange),
            ThemeOption(title: "Low Key", systemImage: "circle.lefthalf.filled", theme: .lowKey, tint: .gray),
            ThemeOption(title: "System", systemImage: "return", theme: .system, tint: swiftColor)
        ]
    }

    private var xcodeTheme: Theme {
        colorScheme == .dark ? .xcodeDark : .xcodeLight
    }

    private var classicTheme: Theme {
        colorScheme == .dark ? .classicDark : .classicLight
    }
    
    private var githubTheme: Theme {
        colorScheme == .dark ? .githubDark : .githubLight
    }
    
    private var solarizedTheme: Theme {
        colorScheme == .dark ? .solarizedDark : .solarizedLight
    }
    
    var swiftColor: Color {
        Color(UIColor.value(forKey: "_swiftColor") as! UIColor)
    }
    
    var darkPurple: Color {
        Color(UIColor.value(forKey: "systemDarkPurpleColor") as! UIColor)
    }
        
    var darkTeal: Color {
        Color(UIColor.value(forKey: "systemDarkTealColor") as! UIColor)
    }
}

fileprivate struct ThemeOption: Identifiable {
    let title: String
    let systemImage: String
    let theme: Theme
    let tint: Color

    var id: String { title }
}



fileprivate struct ThemeButtonStyle: ButtonStyle {
    let foreground: Color
    
    init(_ foreground: Color) {
        self.foreground = foreground
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(foreground.gradient)
            .background {
                Capsule()
                    .stroke(foreground.quaternary, style: .init(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [7, 7]))
                    .fill(foreground.opacity(0.18))
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}



#Preview {
    CodeAppearanceView()
}
