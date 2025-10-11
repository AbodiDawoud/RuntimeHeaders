//
//  CodeAppearanceView.swift
//  HeaderViewer
    

import SwiftUI


struct CodeAppearanceView: View {
    @ObservedObject private var preferences = CodePreferences.shared
    @Environment(\.dismiss) private var dismiss
    

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
                    colorPickerRow("Record", color: $preferences.colors.recordName, icon: "rectangle.on.rectangle", colorStyle: .cyan)
                }
                
                Section("Types") {
                    colorPickerRow("Class", color: $preferences.colors.class, icon: "c.square.fill", colorStyle: .green)
                    colorPickerRow("Protocol", color: $preferences.colors.protocol, icon: "p.square.fill", colorStyle: .mint)
                }
                
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
                    Text("Code Appearance")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                
                ToolbarItem(placement: .topBarTrailing) { dismissButton }
            }
            .toolbarBackground(.visible, for: .navigationBar)
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
            Image(systemName: "chevron.down.circle.fill")
                .foregroundStyle(.gray)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
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
            ForEach(SemanticOptimizedRun.optimize(lineContent: line.content)) {
                switch $0.type {
                case .text(let text):
                    text
                case .navigation(_, let text):
                    text
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
                    Button("Xcode", systemImage: "hammer.fill") {
                        codePreferences.apply(from: xcodeTheme)
                    }
                    .buttonStyle(ThemeButtonStyle(darkTeal))
                    
                    Button("Github", image: .githubFaceFill) {
                        codePreferences.apply(from: githubTheme)
                    }
                    .buttonStyle(ThemeButtonStyle(darkPurple))
                    
                    Button("Solarized", image: .yinYang) {
                        codePreferences.apply(from: solarizedTheme)
                    }
                    .buttonStyle(ThemeButtonStyle(.plum))
                    
                    
                    Button("Default System", systemImage: "return") {
                        codePreferences.apply(from: Theme.system)
                    }
                    .buttonStyle(ThemeButtonStyle(swiftColor))
                }
                .padding(.horizontal, 2)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
    
    private var xcodeTheme: Theme {
        colorScheme == .dark ? .xcodeDark : .xcodeLight
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
            .background(foreground.opacity(0.2).gradient, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .overlay {
                Capsule()
                    .stroke(foreground.quaternary, lineWidth: 1.4)
            }
    }
}



#Preview {
    CodeAppearanceView()
}
