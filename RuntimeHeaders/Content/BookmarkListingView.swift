//
//  BookmarksList.swift
//  HeaderViewer
    

import SwiftUI

struct BookmarkListingView: View {
    @ObservedObject var manager = BookmarksStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var folderName: String = ""
    @State private var showingCreateFolder: Bool = false
    @State private var folderToRename: BookmarkFolder?
    @State private var renameFolderName: String = ""
    
    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if manager.folders.isEmpty {
                    Label("No Folders Yet", systemImage: "folder")
                        .labelStyle(EmptyStatusLabelStyle(.blue, info: "Create a folder to start saving bookmarks."))
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 30) {
                        ForEach(manager.folders) { folder in
                            NavigationLink(value: folder.id) {
                                BookmarkFolderTile(folder: folder)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Rename", systemImage: "pencil") {
                                    folderToRename = folder
                                    renameFolderName = folder.name
                                }
                                
                                if manager.folders.count > 1 {
                                    mergeMenu(for: folder)
                                }
                                
                                Button("Refresh", systemImage: "arrow.clockwise") {
                                    manager.refresh()
                                }
                                
                                Divider()
                                
                                Button("Delete Folder", systemImage: "trash", role: .destructive) {
                                    manager.deleteFolder(folder)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 34)
                }
            }
            .background(Color(.systemGroupedBackground))
            .inlinedNavigationTitle("Bookmarks")
            .animation(.default, value: manager.folders)
            .navigationDestination(for: UUID.self) { folderID in
                BookmarkFolderDetailView(folderID: folderID)
            }
            .alert("New Folder", isPresented: $showingCreateFolder) {
                TextField("Folder name", text: $folderName)
                Button("Create", action: createFolder)
                Button("Cancel", role: .cancel) { folderName = "" }
            } message: {
                Text("Create a folder for organizing bookmarks.")
            }
            .alert("Rename Folder", isPresented: renameAlertBinding) {
                TextField("Folder name", text: $renameFolderName)
                Button("Rename", action: renameFolder)
                Button("Cancel", role: .cancel) {
                    folderToRename = nil
                    renameFolderName = ""
                }
            } message: {
                Text("Give this folder a new name.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        manager.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var renameAlertBinding: Binding<Bool> {
        Binding {
            folderToRename != nil
        } set: { isPresented in
            if isPresented == false {
                folderToRename = nil
            }
        }
    }
    
    private func mergeMenu(for source: BookmarkFolder) -> some View {
        Menu("Merge Into", systemImage: "arrow.triangle.merge") {
            ForEach(manager.folders.filter { $0.id != source.id }) { destination in
                Button(destination.name, systemImage: "folder") {
                    manager.mergeFolder(source, into: destination)
                }
            }
        }
    }
    
    private func createFolder() {
        manager.createFolder(named: folderName)
        folderName = ""
    }
    
    private func renameFolder() {
        guard let folderToRename else { return }
        manager.renameFolder(folderToRename, to: renameFolderName)
        self.folderToRename = nil
        renameFolderName = ""
    }
}

private struct BookmarkFolderTile: View {
    let folder: BookmarkFolder
    
    var body: some View {
        VStack(spacing: 10) {
            Image(.folderIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 56)
            
            Text(folder.name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .contentShape(.rect)
        .accessibilityLabel(folder.name)
    }
}

private struct BookmarkFolderDetailView: View {
    @ObservedObject var manager = BookmarksStore.shared
    let folderID: UUID
    @State private var exportErrorMessage: String?
    
    private var folder: BookmarkFolder? {
        manager.folders.first { $0.id == folderID }
    }
    
    var body: some View {
        List {
            if let folder {
                if folder.bookmarks.isEmpty {
                    Label("No Bookmarks Here", systemImage: "tray")
                        .labelStyle(EmptyStatusLabelStyle(.blue, info: "Add bookmarks to this folder to see them here."))
                } else {
                    Section("^[\(folder.bookmarks.count) Bookmark](inflect: true)") {
                        ForEach(folder.bookmarks) { bookmark in
                            bookmarkRow(bookmark)
                        }
                        .onDelete { offsets in
                            removeBookmarks(at: offsets, in: folder)
                        }
                    }
                }
            } else {
                Label("Folder Not Found", systemImage: "questionmark.folder")
                    .labelStyle(EmptyStatusLabelStyle(.blue, info: "This folder is no longer available."))
            }
        }
        .inlinedNavigationTitle(folder?.name ?? "Bookmarks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Export", systemImage: "square.and.arrow.up", action: exportHeaders)
                    .disabled(folder?.bookmarks.isEmpty ?? true)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    manager.refresh()
                }
            }
        }
        .alert(item: $exportErrorMessage) {
            Alert(title: Text("Export Failed"), message: Text($0), dismissButton: .default(Text("OK")))
        }
    }
    
    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        NavigationLink {
            RuntimeObjectDetail(type: .class(named: bookmark.name), parentPath: bookmark.parentPath)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "doc")
                        .foregroundColor(.aqua)
                    
                    Text(bookmark.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Text(bookmark.lastPathComponent)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .contextMenu {
                Button("Copy File Name", systemImage: "document.on.document") { copy(bookmark.name) }
                Button("Copy File Path", systemImage: "document.on.document") { copy(bookmark.parentPath) }
                Divider()
                Button("Search Web", systemImage: "magnifyingglass.circle") { searchOnSafari(bookmark.name) }
                
                if manager.folders.count > 1 {
                    Divider()
                    moveToFolderMenu(bookmark)
                }
                
                Divider()
                Button("Un-Bookmark", systemImage: "bookmark.slash") {
                    manager.removeBookmark(for: bookmark)
                }
            }
        }
    }
    
    private func moveToFolderMenu(_ bookmark: Bookmark) -> some View {
        Menu("Move to Folder", systemImage: "folder") {
            ForEach(manager.folders) { folder in
                Button {
                    manager.moveBookmark(bookmark, to: folder)
                } label: {
                    Label(folder.name, systemImage: folder.id == folderID ? "checkmark" : "folder")
                }
            }
        }
    }
    
    private func removeBookmarks(at offsets: IndexSet, in folder: BookmarkFolder) {
        for index in offsets where folder.bookmarks.indices.contains(index) {
            manager.removeBookmark(for: folder.bookmarks[index])
        }
    }
    
    private func copy(_ str: String) {
        UIPasteboard.general.string = str
    }
    
    private func searchOnSafari(_ fileName: String) {
        let url = URL(string: "https://google.com/search?q=\(fileName)")!
        UIApplication.shared.open(url)
    }
    
    private func exportHeaders() {
        guard let folder else { return }
        
        do {
            let exportURL = try BookmarkFolderHeaderExporter().exportHeaders(for: folder)
            FileExportCoordinator.shared.export(to: exportURL)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        BookmarkListingView()
            .onAppear {
                BookmarksStore.shared.folders = [
                    .init(
                        name: "UIKit",
                        bookmarks: [
                            .init(name: "UIDevice", parentPath: "UIKit.framework", date: .now),
                            .init(name: "UIViewController", parentPath: "UIKit.framework", date: .now)
                        ]
                    ),
                    .init(
                        name: "Foundation",
                        bookmarks: [
                            .init(name: "NSObject", parentPath: "Foundation.framework", date: .now)
                        ]
                    ),
                    .init(name: "SwiftUI"),
                    .init(name: "CoreGraphics")
                ]
            }
    }
}
