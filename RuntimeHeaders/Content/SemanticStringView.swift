//
//  SemanticStringView.swift
//  HeaderViewer

import SwiftUI
import ClassDumpRuntime
import SyntaxHighlighting


struct SemanticStringView: View {
    @ObservedObject var preferences = CodePreferences.shared
    @ObservedObject var bookmarkManager = BookmarksStore.shared
    
    let semanticString: CDSemanticString
    let fileName: String
    let runtimeType: RuntimeObjectType?
    
    var frameworkPath: String? = nil
    @State private var fileExportCoordinator: FileExportCoordinator?
    @State private var resolvedInstance: ResolvedRuntimeInstance?
    @State private var showRuntimeInspector: Bool = false
    @State private var selectorChooser: RuntimeSelectorChooserState?
    @State private var runtimeInspectorError: String?
    
    private let lines: [SemanticLine]
    private let longestLineIndex: Int?
    private let lineNumberColumnWidth: CGFloat
    
    init(_ semanticString: CDSemanticString, fileName: String, runtimeType: RuntimeObjectType? = nil, nodePath: String? = nil) {
        self.semanticString = semanticString
        self.fileName = fileName
        self.runtimeType = runtimeType
        self.frameworkPath = nodePath
        
        let (lines, longestLineIndex) = semanticLinesFromString(semanticString)
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
            
            if let frameworkPath {
                NavigationLink(value: _ContentView.dscRootNode.node(at: frameworkPath)) {
                    Label("Go to Parent", systemImage: "arrow.right.circle.dotted")
                }
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



struct SemanticLineView: View {
    let line: SemanticLine
    
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(SemanticOptimizedRun.optimize(lineContent: line.content, colors: CodePreferences.shared.colors)) {
                switch $0.type {
                case .text(let text):
                    text
                case .semanticLink(let type, let string, let text):
                    NavigationLink(value: runtimeObjectType(for: type, named: string)) {
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

    private func runtimeObjectType(for semanticType: CDSemanticType, named name: String) -> RuntimeObjectType {
        switch semanticType {
        case .protocol: return .protocol(named: name)
        default: return .class(named: name)
        }
    }
}
