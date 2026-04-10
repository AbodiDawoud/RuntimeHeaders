//
//  SemanticStringView.swift
//  HeaderViewer

import SwiftUI
import ClassDumpRuntime


struct SemanticStringView: View {
    @ObservedObject var preferences = CodePreferences.shared
    @ObservedObject var bookmarkManager = BookmarksStore.shared
    
    let semanticString: CDSemanticString
    let fileName: String
    let runtimeType: RuntimeObjectType?
    
    @State private var fileExportCoordinator: FileExportCoordinator?
    @State private var resolvedInstance: ResolvedRuntimeInstance?
    @State private var showRuntimeInspector: Bool = false
    @State private var selectorChooser: RuntimeSelectorChooserState?
    @State private var runtimeInspectorError: String?
    
    private let lines: [SemanticLine]
    private let longestLineIndex: Int?
    private let lineNumberColumnWidth: CGFloat
    
    init(_ semanticString: CDSemanticString, fileName: String, runtimeType: RuntimeObjectType? = nil) {
        self.semanticString = semanticString
        self.fileName = fileName
        self.runtimeType = runtimeType
        
        let (lines, longestLineIndex) = semanticString.semanticLines()
        self.lines = lines
        self.longestLineIndex = longestLineIndex
        let digitCount = max(2, String(max(lines.count - 1, 0)).count)
        self.lineNumberColumnWidth = CGFloat(digitCount * 9)
    }
    
    var body: some View {
        GeometryReader { geomProxy in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .leading) {
                    // use the longest line to expand the view as much as needed
                    // without having to render all the lines
                    if let longestLineIndex {
                        SemanticLineView(line: lines[longestLineIndex])
                            .padding(.horizontal, 12) // add some extra space, just in case
                            .opacity(0)
                    }
                    
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                if !preferences.hideLineNumbers {
                                    Text("\(index)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                        .frame(width: lineNumberColumnWidth, alignment: .trailing)
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

            if runtimeType?.isClass == true {
                Divider()
                Button("Inspect Live Object", systemImage: "shippingbox", action: openRuntimeInspector)
                Button("Inspect Class Members", systemImage: "shippingbox.and.arrow.backward", action: openClassInspector)
            }
            
            Divider()
            Button(
                bookmarked ? "Un-Bookmark" : "Bookmark",
                systemImage: bookmarked ? "bookmark.slash" : "bookmark",
                action: toggleBookmark
            )
            Button("Save", systemImage: "arrow.down.document", action: saveFileContent)
            Button("Share", systemImage: "square.and.arrow.up", action: presentActivityViewController)
        }
        .fullScreenCover(item: $resolvedInstance) {
            RuntimeObjectInspectorView(resolvedInstance: $0)
        }
        .sheet(item: $selectorChooser) { chooser in
            RuntimeSelectorChooserView(
                className: chooser.className,
                selectorCandidates: chooser.selectorCandidates,
                onSelect: resolveRuntimeInspector
            )
        }
        .alert("Live Object Unavailable", isPresented: runtimeInspectorAlertBinding) {
            Button("OK", role: .cancel) {
                runtimeInspectorError = nil
            }
        } message: {
            Text(runtimeInspectorError ?? "No live object could be resolved.")
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
        fileExportCoordinator = FileExportCoordinator()
        let documentPicker = UIDocumentPickerViewController(forExporting: [location])
        documentPicker.delegate = fileExportCoordinator
        
        let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        let newWindow = UIWindow(windowScene: scene)
        newWindow.windowLevel = .alert + 1
        
        
        newWindow.rootViewController = UIViewController()
        
        fileExportCoordinator!.exportWindow = newWindow
        fileExportCoordinator!.exportWindow!.isHidden = false
        fileExportCoordinator!.exportWindow!.rootViewController!.present(documentPicker, animated: true)
    }
    
    private func presentActivityViewController() {
        let tempUrl = createTempUrl(for: lines)
        ActivityControllerPresenter.present(with: [tempUrl])
    }
    
    func toggleBookmark() {
        bookmarkManager.toggleBookmark(for: fileName)
    }
    
    var bookmarked: Bool {
        return bookmarkManager.isBookmarked(fileName)
    }

    
    private var runtimeInspectorAlertBinding: Binding<Bool> {
        Binding(
            get: { runtimeInspectorError != nil },
            set: { isPresented in
                if isPresented == false {
                    runtimeInspectorError = nil
                }
            }
        )
    }

    func openRuntimeInspector() {
        guard let runtimeType else { return }
        let options = RuntimeInstanceResolver.resolutionOptions(type: runtimeType)

        if let resolvedInstance = options.autoResolvedInstance {
            self.resolvedInstance = resolvedInstance
            return
        }

        if options.manualCandidates.isEmpty {
            runtimeInspectorError = "No shared or singleton-style live object was detected for \(fileName)."
            return
        }

        selectorChooser = RuntimeSelectorChooserState(
            className: fileName,
            selectorCandidates: options.manualCandidates
        )
    }

    func openClassInspector() {
        guard let runtimeType else { return }

        guard let resolvedInstance = RuntimeInstanceResolver.resolveClassObject(type: runtimeType) else {
            runtimeInspectorError = "Class members are unavailable for \(fileName)."
            return
        }

        self.resolvedInstance = resolvedInstance
    }

    func resolveRuntimeInspector(candidate: RuntimeInstanceCandidate) {
        guard let runtimeType else { return }
        selectorChooser = nil

        guard let resolvedInstance = RuntimeInstanceResolver.resolve(type: runtimeType, candidate: candidate) else {
            runtimeInspectorError = "'\(candidate.displayName)' did not resolve a live object for \(fileName)."
            return
        }

        self.resolvedInstance = resolvedInstance
    }
    
    
    private class FileExportCoordinator: NSObject, UIDocumentPickerDelegate {
        var exportWindow: UIWindow?

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print(#function)
            controller.dismiss(animated: true)
            exportWindow!.rootViewController = nil
            exportWindow = nil
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print(#function, urls)
            controller.dismiss(animated: true)
            exportWindow = nil
        }
    }
}


private struct RuntimeSelectorChooserView: View {
    let className: String
    let selectorCandidates: [RuntimeInstanceCandidate]
    let onSelect: (RuntimeInstanceCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var customSelectorName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Detected Class Getters") {
                    if filteredCandidates.isEmpty {
                        Text("No matching selectors")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredCandidates) { candidate in
                            Button {
                                submit(candidate)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.displayName)
                                        .font(.headline)
                                    Text(candidate.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    TextField("sharedSession", text: $customSelectorName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Try Selector", systemImage: "play.circle.fill") {
                        submitCustomSelector()
                    }
                    .disabled(trimmedCustomSelector.isEmpty)
                } header: {
                    Text("Custom Selector")
                } footer: {
                    Text("Choose a detected live-object entry point or enter another zero-argument class selector for \(className).")
                }
            }
            .navigationTitle("Choose Live Object Getter")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredCandidates: [RuntimeInstanceCandidate] {
        if searchText.isEmpty { return selectorCandidates }
        return selectorCandidates.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.selectorName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var trimmedCustomSelector: String {
        customSelectorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit(_ candidate: RuntimeInstanceCandidate) {
        dismiss()
        onSelect(candidate)
    }

    private func submitCustomSelector() {
        let trimmedName = trimmedCustomSelector
        guard trimmedName.isEmpty == false else { return }
        let candidate = RuntimeInstanceCandidate(
            selectorName: trimmedName,
            displayName: trimmedName,
            subtitle: "Custom zero-argument class getter",
            kind: .classGetter
        )
        dismiss()
        onSelect(candidate)
    }
}


private struct RuntimeSelectorChooserState: Identifiable {
    let className: String
    let selectorCandidates: [RuntimeInstanceCandidate]

    var id: String { className }
}




// MARK: -  Semantic Line

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
        // Preserve the full rendered width so long declarations scroll horizontally
        // instead of being compressed and truncated by the surrounding layout.
        .fixedSize(horizontal: true, vertical: false)
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
