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
            if SettingsManager.shared.preferences.historyEnabled {
                historyManager.addObject(newValue)
            }
        }
    }
}


private struct _ContentView: View {
    private static let dscRootNode = CDUtilities.dyldSharedCacheImageRootNode
    @Binding var selectedObject: RuntimeObjectType?
    @StateObject private var viewModel = RuntimeObjectsViewModel()
    
    @State private var showBookmarkView: Bool = false
    @Namespace private var animation
    
    
    var body: some View {
        NavigationStack {
            Form {
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
                            Text("This list is a bit buggy and slow to deal with, use with caution.")
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)
                        }
                    }
                }
                
                Section {
                    Button {
                        showBookmarkView.toggle()
                    } label: {
                        Label("Bookmarks", systemImage: "bookmark")
                            .backport { view in
                                if #available(iOS 18, *) {
                                    view.matchedTransitionSource(id: "bookmarks", in: animation)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .inlinedNavigationTitle("Header Viewer")
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
                Image(.logoGithubCircleFill)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
    }
    
    func assignNodePath(_ path: String) {
        if BookmarkManager.lastNodePath == path { return }
        BookmarkManager.lastNodePath = path
    }
}
