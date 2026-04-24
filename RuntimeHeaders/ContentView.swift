//
//  ContentView.swift
//  HeaderViewer


import SwiftUI
import ClassDumpRuntime


struct ContentView: View { 
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(HistoryManager.self) private var historyManager
    
    
    var body: some View {
        NavigationSplitView {
            _ContentView()
        } detail: {
            if let selectedObject = navigation.selectedObject {
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
        .onChange(of: navigation.selectedObject) { _, newValue in
            if PreferenceController.shared.preferences.historyEnabled {
                historyManager.addObject(newValue)
            }
        }
    }
}


struct _ContentView: View {
    static let dscRootNode = CDUtilities.dyldSharedCacheImageRootNode
    @StateObject private var viewModel = RuntimeObjectsViewModel()
    
    @State private var showBookmarkView: Bool = false
    @Namespace private var animation
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var navigation: AppNavigation
    
    var body: some View {
        NavigationStack(path: $navigation.sourcePath) {
            Form {
                FFContainerView()
                LSContainerView()
                
                Section("Root") {
                    NavigationLink(value: Self.dscRootNode) {
                        Label("System Images", systemImage: "folder.badge.gear")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    NavigationLink {
                        RuntimeObjectsList(
                            runtimeObjects: viewModel.runtimeObjects,
                            searchString: $viewModel.searchString,
                            searchScope: $viewModel.searchScope
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Runtime Objects", image: "document.badge.gearshape.fill")
                                .font(.system(size: 16, weight: .medium))
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
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Runtime Headers")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(for: NamedNode.self) { namedNode in
                if namedNode.isLeaf {
                    ImageRuntimeObjectsView(namedNode: namedNode)
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .stroke(Color(white: 0.25), lineWidth: 0.8)
                            .fill(Color(white: 0.15))
                    }
                
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.gray.opacity(0.75))
            }
            .font(.footnote.weight(.medium))
        } label: {
            Text("Bookmarks")
        }
    }
    
    func assignNodePath(_ path: String) {
        LastNodeTracker.path = path
    }
}
