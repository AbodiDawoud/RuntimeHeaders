//
//  BookmarksList.swift
//  HeaderViewer
    

import SwiftUI
import Toasts

struct BookmarkListingView: View {
    @ObservedObject var manager = BookmarksStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    @Environment(\.colorScheme) private var scheme
    
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
                        .labelStyle(EmptyStatusLabelStyle(.blue, secondary: .blue, info: "Create a folder to start saving bookmarks."))
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
                                
                                Button("Refresh", systemImage: "arrow.clockwise", action: manager.refresh)
                                
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
                        hapticFeedback(.light)
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
                        hapticFeedback(.soft)
                        showingCreateFolder = true
                    } label: {
                        Text("New Folder")
                            .font(.system(.subheadline, design: .default, weight: .medium))
                            .foregroundStyle(.blue.gradient)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .stroke(Color.blue.opacity(0.08), lineWidth: 0.9)
                                    .fill(.blue.quinary.opacity(scheme == .light ? 0.4 : 0.95))
                            )
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
        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.createFolder(named: trimmedName)

        folderName = ""
    }
    
    private func renameFolder() {
        guard let folderToRename else { return }
        let trimmedName = renameFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.renameFolder(folderToRename, to: trimmedName)

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
    @Environment(\.presentToast) private var presentToast
    let folderID: UUID
    @State private var exportErrorMessage: String?
    @State private var editMode: EditMode = .inactive
    @State private var selectedBookmarkIDs = Set<Bookmark.ID>()
    
    private var folder: BookmarkFolder? {
        manager.folders.first { $0.id == folderID }
    }

    private var isEditing: Bool {
        editMode.isEditing
    }

    private var selectedBookmarks: [Bookmark] {
        guard let folder else { return [] }
        return folder.bookmarks.filter { selectedBookmarkIDs.contains($0.id) }
    }
    
    var body: some View {
        List(selection: $selectedBookmarkIDs) {
            if let folder {
                if folder.bookmarks.isEmpty {
                    Label("No Bookmarks Here", systemImage: "tray")
                        .labelStyle(EmptyStatusLabelStyle(.blue, info: "Add bookmarks to this folder to see them here."))
                } else {
                    Section("^[\(folder.bookmarks.count) Bookmark](inflect: true)") {
                        ForEach(folder.bookmarks) { bookmark in
                            bookmarkRow(bookmark)
                                .tag(bookmark.id)
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
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { _, newValue in
            if newValue.isEditing == false {
                selectedBookmarkIDs.removeAll()
            }
        }
        .onChange(of: folder?.bookmarks) { _, bookmarks in
            let availableIDs = Set(bookmarks?.map(\.id) ?? [])
            selectedBookmarkIDs = selectedBookmarkIDs.intersection(availableIDs)
        }
        .toolbar {
            if isEditing == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("", image: .multiSelect) {
                        withAnimation { editMode = .active }
                    }
                    
                    .buttonStyle(.plain)
                    .disabled(folder?.bookmarks.isEmpty ?? true)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise", action: manager.refresh)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }

            if isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { editMode = .inactive }
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold).font(.footnote)
                            .foregroundStyle(.white)
                            .frame(width: 65, height: 28)
                            .background(.indigo, in: .capsule)
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(selectionToggleTitle, systemImage: selectionToggleIcon, action: toggleSelection)
                        .disabled(folder?.bookmarks.isEmpty ?? true)

                    Spacer()

                    HStack {
                        Button("Share", systemImage: "square.and.arrow.up", action: shareSelectedBookmarks)
                            .disabled(selectedBookmarkIDs.isEmpty)
                            
                        Button("Unmark", systemImage: "bookmark.slash", role: .destructive, action: unmarkSelectedBookmarks)
                            .disabled(selectedBookmarkIDs.isEmpty)
                    }
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
                    presentToast(.appToast(icon: "bookmark.slash", message: "Removed bookmark"))
                }
            }
        }
    }
    
    private func moveToFolderMenu(_ bookmark: Bookmark) -> some View {
        Menu("Move to Folder", systemImage: "folder") {
            ForEach(manager.folders) { folder in
                Button {
                    manager.moveBookmark(bookmark, to: folder)
                    presentToast(.appToast(icon: "folder", message: "Moved to \(folder.name)"))
                } label: {
                    Label(folder.name, systemImage: folder.id == folderID ? "checkmark" : "folder")
                }
            }
        }
    }
    
    private func removeBookmarks(at offsets: IndexSet, in folder: BookmarkFolder) {
        let bookmarksToRemove = offsets.compactMap { index in
            folder.bookmarks.indices.contains(index) ? folder.bookmarks[index] : nil
        }
        manager.removeBookmarks(bookmarksToRemove)
        
        if offsets.isEmpty == false {
            presentToast(.appToast(icon: "bookmark.slash", message: "Removed bookmark"))
        }
    }
    
    private func copy(_ str: String) {
        UIPasteboard.general.string = str
        presentToast(.appToast(icon: "doc.on.doc", message: "Copied"))
    }
    
    private func searchOnSafari(_ fileName: String) {
        let url = URL(string: "https://google.com/search?q=\(fileName)")!
        UIApplication.shared.open(url)
    }
    
    private func exportHeaders() {
        guard let folder else { return }
        exportHeaders(for: folder)
    }

    private func shareSelectedBookmarks() {
        guard let folder, selectedBookmarks.isEmpty == false else { return }
        let folderName = selectedBookmarks.count == folder.bookmarks.count ? folder.name : "\(folder.name) Selection"
        let selectedFolder = BookmarkFolder(
            id: folder.id,
            name: folderName,
            date: folder.date,
            bookmarks: selectedBookmarks
        )
        exportHeaders(for: selectedFolder)
    }

    private func exportHeaders(for folder: BookmarkFolder) {
        guard folder.bookmarks.isEmpty == false else { return }
        
        do {
            let exportURL = try BookmarkFolderHeaderExporter().exportHeaders(for: folder)
            FileExportCoordinator.shared.export(to: exportURL)
            presentToast(.appToast(icon: "square.and.arrow.up", message: "Export ready"))
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func unmarkSelectedBookmarks() {
        let bookmarksToRemove = selectedBookmarks
        guard bookmarksToRemove.isEmpty == false else { return }

        manager.removeBookmarks(bookmarksToRemove)
        let removedCount = bookmarksToRemove.count
        selectedBookmarkIDs.removeAll()

        if folder?.bookmarks.isEmpty ?? true {
            editMode = .inactive
        }

        presentToast(.appToast(icon: "bookmark.slash", message: "Removed \(removedCount) bookmark\(removedCount == 1 ? "" : "s")"))
    }

    private func toggleSelection() {
        guard let folder else { return }
        let allIDs = Set(folder.bookmarks.map(\.id))

        if selectedBookmarkIDs == allIDs {
            selectedBookmarkIDs.removeAll()
        } else {
            selectedBookmarkIDs = allIDs
        }
    }

    private var selectionToggleTitle: String {
        guard let folder else { return "Select All" }
        return selectedBookmarkIDs.count == folder.bookmarks.count ? "Clear" : "Select All"
    }

    private var selectionToggleIcon: String {
        guard let folder else { return "checkmark.circle" }
        return selectedBookmarkIDs.count == folder.bookmarks.count ? "xmark.circle" : "checkmark.circle"
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
