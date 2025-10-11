//
//  NamedNodeView.swift
//  HeaderViewer


import SwiftUI
import ClassDumpRuntime


struct NamedNodeRow: View {
    @EnvironmentObject private var listings: RuntimeListings
    @Environment(\.openURL) private var openUrl
    @State private var searchText: String = ""
    let node: NamedNode
    
    
    var body: some View {
        List(children, id: \.name) { child in
            let canLoad = couldLoad(node: child)
            NavigationLink(value: child) {
                HStack {
                    Image(
                        systemName: child.isLeaf == false ? "folder" :
                                    canLoad ? "lock.document" : "doc"
                    ).foregroundColor(canLoad ? .tangerine : .blue)
                    
                    Text(child.name)
                }
                .accessibilityLabel(child.name)
                .contextMenu {
                    Button("Copy Name", systemImage: "document.on.document") { copy(child.name) }
                    Button("Copy Path", systemImage: "document.on.document") { copy(child.path) }
                    Divider()
                    Button("Search Web", systemImage: "safari") { searchWeb(child.name) }
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
    
    func searchWeb(_ string: String) {
        let url = URL(string: "https://google.com/search?q=\(node.name)")!
        openUrl(url)
    }
}
