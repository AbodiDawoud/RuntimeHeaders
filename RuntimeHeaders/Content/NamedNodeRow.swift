//
//  NamedNodeView.swift
//  HeaderViewer


import SwiftUI
import ClassDumpRuntime


struct NamedNodeRow: View {
    @EnvironmentObject private var listings: RuntimeListings
    @Environment(\.openURL) private var openUrl
    @State private var searchText: String = ""
    @State private var isExporting: Bool = false
    @State private var exportErrorMessage: String?
    @State private var fileExportCoordinator: FileExportCoordinator?
    let node: NamedNode
    
    
    var body: some View {
        List(children, id: \.name) { child in
            let canLoad = couldLoad(node: child)
            NavigationLink(value: child) {
                HStack {
                    Image(
                        systemName: child.isLeaf == false ? "folder" :
                                    canLoad ? "lock.document" : "building.columns"
                    ).foregroundColor(canLoad ? .tangerine : .blue)
                    
                    Text(child.name)
                }
                .accessibilityLabel(child.name)
                .contextMenu {
                    Button("Copy Name", systemImage: "square.on.square.dashed") { copy(child.name) }
                    Button("Copy Path", systemImage: "square.on.square.dashed") { copy(child.path) }
                    Divider()
                    Button("Search Web", systemImage: "safari") { searchWeb(child.name) }
                    Button("Export Node", systemImage: "square.and.arrow.up") { exportNode(child) }
                    Divider()
                    if canLoad {
                        Button {
                            try? CDUtilities.loadImage(at: child.path)
                        } label: {
                            Label("Load", systemImage: "ellipsis")
                        }
                    }
                }
            }
        }
        .autocorrectionDisabled() // turn of auto-correct for the search field
        .navigationTitle((node.name.isEmpty && node.parent == nil) ? "/" : node.name)
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if isExporting {
                ProgressView("Exporting Headers")
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert(item: $exportErrorMessage) {
            Alert(title: Text("Export Failed"), message: Text($0), dismissButton: .default(Text("OK")))
        }
    }
    
    private var children: [NamedNode] {
        if searchText.isEmpty { return node.children }
        return node.children.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func couldLoad(node: NamedNode) -> Bool {
        node.isLeaf && !listings.isImageLoaded(path: node.path)
    }
    
    func copy(_ string: String) {
        UIPasteboard.general.string = string
    }
    
    func searchWeb(_ query: String) {
        let url = URL(string: "https://google.com/search?q=\(query)")!
        openUrl(url)
    }
    
    func exportNode(_ selectedNode: NamedNode? = nil) {
        if isExporting { return }
        
        isExporting = true
        let exportTarget = selectedNode ?? node
        let exporter = NamedNodeExporter(listings: listings)
        
        Task {
            do {
                let exportURL = try exporter.exportHeaders(for: exportTarget)
                presentDocumentPicker(for: exportURL)
            } catch {
                exportErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            
            isExporting = false
        }
    }
    
    private func presentDocumentPicker(for location: URL) {
        let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        
        fileExportCoordinator = FileExportCoordinator()
        
        let documentPicker = UIDocumentPickerViewController(forExporting: [location])
        documentPicker.delegate = fileExportCoordinator
        
        let exportWindow = UIWindow(windowScene: scene)
        exportWindow.windowLevel = .alert + 1
        exportWindow.rootViewController = UIViewController()
        
        fileExportCoordinator?.exportWindow = exportWindow
        exportWindow.isHidden = false
        exportWindow.rootViewController?.present(documentPicker, animated: true)
    }
}
