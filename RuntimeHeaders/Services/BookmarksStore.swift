//
//  BookmarManager.swift
//  HeaderViewer
    

import Foundation

class BookmarksStore: ObservableObject {
    static let shared = BookmarksStore()
    
    @Published var folders: [BookmarkFolder] = []
    
    private let userDefaults: UserDefaults
    private let userDefaultsKey = "bookmarks"
    private let foldersUserDefaultsKey = "bookmarkFolders"
    
    var bookmarks: [Bookmark] {
        folders.flatMap(\.bookmarks)
    }
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: "BookmarkManager")!
        loadBookmarks()
    }
    
    func toggleBookmark(for imageName: String) {
        guard let parent = LastNodeTracker.path else { return }
        let bookmark = Bookmark(name: imageName, parentPath: parent, date: Date.now)
        
        if isBookmarked(bookmark) {
            removeBookmark(for: bookmark)
        } else {
            addBookmark(bookmark, to: defaultFolderID())
        }
    }
    
    @discardableResult
    func addBookmark(imageName: String, parent: String) -> Int {
        let bookmark = Bookmark(name: imageName, parentPath: parent, date: Date.now)
        addBookmark(bookmark, to: defaultFolderID())
        return bookmarks.count - 1
    }
    
    func addBookmark(imageName: String, parent: String, to folder: BookmarkFolder) {
        let bookmark = Bookmark(name: imageName, parentPath: parent, date: Date.now)
        addBookmark(bookmark, to: folder.id)
    }
    
    func addBookmark(_ bookmark: Bookmark, to folderID: UUID) {
        removeBookmark(for: bookmark, shouldSync: false)
        
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].bookmarks.insert(bookmark, at: 0)
        syncFolders()
    }
    
    func removeBookmark(at index: IndexSet) {
        let allBookmarks = bookmarks
        
        for i in index where allBookmarks.indices.contains(i) {
            removeBookmark(for: allBookmarks[i], shouldSync: false)
        }
        
        syncFolders()
    }
    
    func removeBookmark(for bookmark: Bookmark) {
        removeBookmark(for: bookmark, shouldSync: true)
    }
    
    func createFolder(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        folders.insert(BookmarkFolder(name: trimmedName), at: 0)
        syncFolders()
    }
    
    func renameFolder(_ folder: BookmarkFolder, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }
        
        folders[index].name = trimmedName
        syncFolders()
    }
    
    func deleteFolder(_ folder: BookmarkFolder) {
        folders.removeAll { $0.id == folder.id }
        syncFolders()
    }
    
    func mergeFolder(_ source: BookmarkFolder, into destination: BookmarkFolder) {
        guard source.id != destination.id,
              let sourceIndex = folders.firstIndex(where: { $0.id == source.id }),
              let destinationIndex = folders.firstIndex(where: { $0.id == destination.id }) else {
            return
        }
        
        let bookmarksToMove = folders[sourceIndex].bookmarks.filter { bookmark in
            folders[destinationIndex].bookmarks.contains(bookmark) == false
        }
        
        folders[destinationIndex].bookmarks.insert(contentsOf: bookmarksToMove, at: 0)
        folders.remove(at: sourceIndex)
        syncFolders()
    }
    
    func moveBookmark(_ bookmark: Bookmark, to folder: BookmarkFolder) {
        addBookmark(bookmark, to: folder.id)
    }
    
    func isBookmarked(_ imageName: String) -> Bool {
        guard let path = LastNodeTracker.path else { return false }
        return isBookmarked(Bookmark(name: imageName, parentPath: path, date: .now))
    }
    
    func folderContaining(_ bookmark: Bookmark) -> BookmarkFolder? {
        folders.first { folder in
            folder.bookmarks.contains(bookmark)
        }
    }
    
    func clearBookmarks() {
        folders.removeAll()
        syncFolders()
    }
    
    func refresh() {
        loadBookmarks()
    }
    
    private func defaultFolderID() -> UUID {
        if let firstFolder = folders.first {
            return firstFolder.id
        }
        
        let folder = BookmarkFolder(name: "Bookmarks")
        folders.append(folder)
        syncFolders()
        return folder.id
    }
    
    private func isBookmarked(_ bookmark: Bookmark) -> Bool {
        bookmarks.contains(bookmark)
    }
    
    private func removeBookmark(for bookmark: Bookmark, shouldSync: Bool) {
        for index in folders.indices {
            folders[index].bookmarks.removeAll { $0 == bookmark }
        }
        
        if shouldSync {
            syncFolders()
        }
    }
    
    private func syncFolders() {
        let data = try? JSONEncoder().encode(folders)
        userDefaults.set(data, forKey: foldersUserDefaultsKey)
    }
    
    private func loadBookmarks() {
        let legacyBookmarks = loadLegacyBookmarks()
        
        if let foldersData = userDefaults.data(forKey: foldersUserDefaultsKey),
           let decodedFolders = try? JSONDecoder().decode([BookmarkFolder].self, from: foldersData) {
            folders = decodedFolders
        }
        
        if folders.isEmpty, !legacyBookmarks.isEmpty {
            folders = [BookmarkFolder(name: "Bookmarks", bookmarks: legacyBookmarks)]
            syncFolders()
        }
    }
    
    private func loadLegacyBookmarks() -> [Bookmark] {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let decodedBookmarks = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return []
        }
        
        return decodedBookmarks
    }
    
    var isBookmarkEmpty: Bool {
        bookmarks.isEmpty
    }
}
