//
//  ContentView.swift
//  HeaderViewer


import SwiftUI
import ClassDumpRuntime


struct ContentView: View { 
    @State private var selectedObject: RuntimeObjectType?
    @EnvironmentObject private var historyManager: HistoryManager
    
    
    
    var body: some View {
        NavigationSplitView {
            _ContentView(selectedObject: $selectedObject)
        } detail: {
            if let selectedObject {
                NavigationStack {
                    RuntimeObjectDetail(type: selectedObject)
                        .navigationDestination(for: RuntimeObjectType.self) {
                            RuntimeObjectDetail(type: $0)
                        }
                }
            } else {
                Text("Select a class or protocol").scenePadding()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedObject) { _, newValue in
            if PreferenceController.shared.preferences.historyEnabled {
                historyManager.addObject(newValue)
            }
        }
    }
}


struct _ContentView: View {
    static let dscRootNode = CDUtilities.dyldSharedCacheImageRootNode
    @Binding var selectedObject: RuntimeObjectType?
    @StateObject private var viewModel = RuntimeObjectsViewModel()
    
    @State private var showBookmarkView: Bool = false
    @State private var navigationPath: [NamedNode] = []
    @Namespace private var animation
    @Environment(\.colorScheme) private var colorScheme

    init(selectedObject: Binding<RuntimeObjectType?>) {
        _selectedObject = selectedObject
        
        if !PreferenceController.shared.preferences.restoreLastFrameworkOnLaunch { return }
        _navigationPath = State(initialValue: LastNodeTracker.namedNode.map { [$0] } ?? [])
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                FFContainerView()
                
                Section("Root") {
                    NavigationLink(value: Self.dscRootNode) {
                        Label("System Images", systemImage: "folder.badge.gear")
                    }
                    
                    NavigationLink {
                        RuntimeObjectsList(
                            runtimeObjects: viewModel.runtimeObjects,
                            selectedObject: $selectedObject,
                            searchString: $viewModel.searchString,
                            searchScope: $viewModel.searchScope
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Runtime Objects", image: "document.badge.gearshape.fill")
                            Text("This list is a bit buggy and slow to deal with on older devices, use with caution.")
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)
                        }
                    }
                }
                
                Section {
                    Button {
                        showBookmarkView.toggle()
                    } label: {
                        bookmarksButtonLabel
                            .backport { view in
                                if #available(iOS 18, *) {
                                    view.matchedTransitionSource(id: "bookmarks", in: animation)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Header Viewer")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(for: NamedNode.self) { namedNode in
                if namedNode.isLeaf {
                    ImageRuntimeObjectsView(namedNode: namedNode, selection: $selectedObject)
                        .onAppear { assignNodePath(namedNode.path) }
                } else {
                    NamedNodeRow(node: namedNode)
                        .environmentObject(RuntimeListings.shared)
                }
            }
            .sheet(isPresented: $showBookmarkView) {
                BookmarkListingView()
                    .backport { view in
                        if #available(iOS 18, *) {
                            view
                                .disableZoomInteractiveDismiiss()
                                .navigationTransition(.zoom(sourceID: "bookmarks", in: animation))
                        }
                    }
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                let githubLink = URL(string: "https://github.com/leptos-null/HeaderViewer")!
                UIApplication.shared.open(githubLink)
            } label: {
                Image(.githubFaceFill)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var bookmarksButtonLabel: some View {
        LabeledContent {
            HStack(spacing: 12) {
                Text("\(BookmarksStore.shared.bookmarks.count)")
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4.6)
                    .background(Color(white: colorScheme == .dark ? 0.145 : 0.965), in: .rect(cornerRadius: 8))
                
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.gray.opacity(0.75))
            }
            .font(.footnote.weight(.medium))
        } label: {
            Label("Bookmarks", systemImage: "bookmark")
        }
    }
    
    func assignNodePath(_ path: String) {
        LastNodeTracker.path = path
    }
}

/// keeps track of the last opened bundle or framework.
enum LastNodeTracker {
    private static let pathKey = "lastNamedNodePath"

    static var path: String? {
        get {
            UserDefaults.standard.string(forKey: pathKey)
        }
        set {
            
            UserDefaults.standard.set(newValue, forKey: pathKey)
        }
    }
    
    static var namedNode: NamedNode? {
        get {
            guard let path else { return nil }
            return _ContentView.dscRootNode.node(at: path)
        }
        set {
            path = newValue?.path
        }
    }
}

