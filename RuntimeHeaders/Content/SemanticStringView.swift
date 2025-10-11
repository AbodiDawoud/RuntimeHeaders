//
//  SemanticStringView.swift
//  HeaderViewer

import SwiftUI
import ClassDumpRuntime


struct SemanticStringView: View {
    @ObservedObject var preferences = CodePreferences.shared
    @ObservedObject var bookmarkManager = BookmarkManager.shared
    
    let semanticString: CDSemanticString
    let fileName: String
    
    
    private let lines: [SemanticLine]
    private let longestLineIndex: Int?
    
    init(_ semanticString: CDSemanticString, fileName: String) {
        self.semanticString = semanticString
        self.fileName = fileName
        
        let (lines, longestLineIndex) = semanticString.semanticLines()
        self.lines = lines
        self.longestLineIndex = longestLineIndex
    }
    
    var body: some View {
        GeometryReader { geomProxy in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .leading) {
                    // use the longest line to expand the view as much as needed
                    // without having to render all the lines
                    if let longestLineIndex {
                        SemanticLineView(line: lines[longestLineIndex])
                            .padding(.horizontal, 0) // add some extra space, just in case
                            .opacity(0)
                    }
                    
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                if !preferences.hideLineNumbers {
                                    Text("\(index)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                SemanticLineView(line: lines[index])
                            }
                        }
                    }
                    .accessibilityTextContentType(.sourceCode)
                }
                .font(preferences.swiftUIFont)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .scenePadding()
                .frame(
                    minWidth: geomProxy.size.width, maxWidth: .infinity,
                    minHeight: geomProxy.size.height, maxHeight: .infinity,
                    alignment: .topLeading
                )
            }
            .animation(.snappy, value: geomProxy.size)
        }
        .toolbarTitleMenu {
            Button("File Name", systemImage: "document.on.document", action: copyFileName)
            Button("File Content", systemImage: "document.on.document", action: copyFileContent)
            
            Divider()
            
            Button("Search Web", systemImage: "magnifyingglass.circle", action: searchOnSafari)
            
            Divider()
            Button(
                bookmarked ? "Un-Bookmark" : "Bookmark",
                systemImage: bookmarked ? "bookmark.slash" : "bookmark",
                action: toggleBookmark
            )
            Button("Save", systemImage: "arrow.down.document", action: saveFileContent)
            Button("Share", systemImage: "square.and.arrow.up", action: presentActivityViewController)
        }
    }

    func copyFileName() {
        UIPasteboard.general.string = fileName
    }
    
    func copyFileContent() {
        let content = getFileContent(lines)
        UIPasteboard.general.string = content
    }
    
    func saveFileContent() {
        let tempUrl = createTempUrl(for: lines)
        presentDocumentPicker(for: tempUrl)
    }
    
    func searchOnSafari() {
        let url = URL(string: "https://google.com/search?q=\(fileName)")!
        UIApplication.shared.open(url)
    }
    
    private func createTempUrl(for lines: [SemanticLine]) -> URL {
        let content = getFileContent(lines)
        let manager = FileManager.default
        let fileUrl = manager.temporaryDirectory.appendingPathComponent("\(fileName).h")
        
        if manager.fileExists(atPath: fileUrl.path) {
            print(">> File already exists at:", fileUrl.path)
            return fileUrl
        }
        
        let data = content.data(using: .utf8)
        try? data?.write(to: fileUrl)
        return fileUrl
    }
    
    private func getFileContent(_ lines: [SemanticLine]) -> String {
        var stringContent: [String] = []
        
        lines.forEach { line in
            var lineContent = ""
            line.content.forEach { run in
                lineContent += run.string
            }
            stringContent.append(lineContent)
        }
        
        return stringContent.joined(separator: "\n")
    }
    
    private func presentDocumentPicker(for location: URL) {
        let keyWindow = UIWindow.value(forKey: "keyWindow") as! UIWindow
        let documentPicker = UIDocumentPickerViewController(forExporting: [location])

        keyWindow.rootViewController!.present(documentPicker, animated: true)
    }
    
    private func presentActivityViewController() {
        let tempUrl = createTempUrl(for: lines)
        let keyWindow = UIWindow.value(forKey: "keyWindow") as! UIWindow
        
        let controller = UIActivityViewController(activityItems: [tempUrl], applicationActivities: nil)
        keyWindow.rootViewController!.present(controller, animated: true)
    }
    
    func toggleBookmark() {
        bookmarkManager.toggleBookmark(for: fileName)
    }
    
    var bookmarked: Bool {
        return bookmarkManager.isBookmarked(fileName)
    }
}

struct SemanticLineView: View {
    let line: SemanticLine
    
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(SemanticOptimizedRun.optimize(lineContent: line.content)) {
                switch $0.type {
                case .text(let text):
                    text
                case .navigation(let runtimeObjectType, let text):
                    NavigationLink(value: runtimeObjectType) {
                        text
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .lineLimit(1, reservesSpace: true)
        .padding(.vertical, 1) // effectively line spacing
    }
}





struct SemanticLine: Identifiable {
    let number: Int
    let content: [SemanticRun]
    
    var id: Int { number }
}

struct SemanticRun: Identifiable {
    let id: Int  // it is the caller's responsibility to set a unique id relative to the container
    let string: String
    let type: CDSemanticType
}


enum SemanticOptimizedType {
    case text(Text)
    case navigation(RuntimeObjectType, Text)
}

struct SemanticOptimizedRun: Identifiable {
    let id: Int
    let type: SemanticOptimizedType
    
    
    static func optimize(lineContent: [SemanticRun]) -> [Self] {
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
            
            func pushNavigation(_ objectType: RuntimeObjectType, _ provider: (Text) -> Text) {
                pushRun()
                let text = provider(
                    Text(content.string)
                )

                ret.append(
                    .init(id: ret.count, type: .navigation(objectType, text))
                )
            }
             
            switch content.type {
            case .standard:
                pushText {
                    $0.foregroundColor(CodePreferences.shared.colors.standard)
                }
            case .comment:
                pushText {
                    $0.foregroundColor(CodePreferences.shared.colors.comment)
                }
            case .keyword:
                pushText {
                    $0.foregroundColor(CodePreferences.shared.colors.keyword)
                }
            case .variable:
                pushText {
                    $0.foregroundColor(CodePreferences.shared.colors.variable)
                }
            case .recordName:
                pushText {
                    $0.foregroundColor(CodePreferences.shared.colors.recordName)
                }
            case .class:
                pushNavigation(.class(named: content.string)) {
                    $0.foregroundColor(CodePreferences.shared.colors.class)
                }
            case .protocol:
                pushNavigation(.protocol(named: content.string)) {
                    $0.foregroundColor(CodePreferences.shared.colors.protocol)
                }
            case .numeric:
                pushText {
                    $0.foregroundColor(CodePreferences.shared.colors.number)
                }
            default:
                pushText {
                    $0.foregroundColor(CodePreferences.shared.colors.defaultValue)
                }
            }
        }
        
        pushRun()
        
        return ret
    }
}


private extension CDSemanticString {
    func semanticLines() -> (lines: [SemanticLine], longestLineIndex: Int?) {
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
        
        self.enumerateTypes { str, type in
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
}
