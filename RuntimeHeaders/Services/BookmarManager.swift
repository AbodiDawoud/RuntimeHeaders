//
//  BookmarManager.swift
//  HeaderViewer
    

import Foundation

class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()
    
    // keeps track of the last opened bundle or framework.
    // This property will be tied to saved bookmarks for dynamic load later on.
    static var lastNodePath: String?
    
    
    @Published var bookmarks: [Bookmark] = []
    
    private let userDefaults: UserDefaults
    private let userDefaultsKey = "bookmarks"

    
    private init() {
        self.userDefaults = UserDefaults(suiteName: "BookmarkManager")!
        loadBookmarks()
        debugBookmarks()
    }
    
    func toggleBookmark(for imageName: String) {
        guard let parent = BookmarkManager.lastNodePath else { return }
        let b = Bookmark(name: imageName, parentPath: parent, date: Date.now)
        
        if let index = bookmarks.firstIndex(of: b) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.append(b)
        }
        
        syncBookmarks()
        debugBookmarks()
    }
    
    @discardableResult
    func addBookmark(imageName: String, parent: String) -> Int {
        let newBookmark = Bookmark(name: imageName, parentPath: parent, date: Date.now)
        bookmarks.insert(newBookmark, at: 0)
        syncBookmarks()
        return bookmarks.count - 1
    }
    
    func removeBookmark(at index: IndexSet) {
        for i in index {
            bookmarks.remove(at: i)
        }
        syncBookmarks()
    }
    
    func removeBookmark(for bookmark: Bookmark) {
        bookmarks.removeAll { $0.name == bookmark.name && $0.parentPath == bookmark.parentPath }
        syncBookmarks()
    }
    
    func clearBookmarks() {
        bookmarks.removeAll()
        syncBookmarks()
    }
    
    func isBookmarked(_ imageName: String) -> Bool {
        guard let path = BookmarkManager.lastNodePath else { return false }
        return bookmarks.contains { $0.name == imageName && $0.parentPath == path }
    }
    
    private func syncBookmarks() {
        let data = try? JSONEncoder().encode(bookmarks)
        userDefaults.set(data, forKey: userDefaultsKey)
    }
    
    private func loadBookmarks() {
        guard let data = userDefaults.data(forKey: userDefaultsKey) else { return }
        bookmarks = try! JSONDecoder().decode([Bookmark].self, from: data)
    }
    
    private func debugBookmarks() {
        print("Bookmarks:")
        bookmarks.forEach { print($0) }
    }
    
    var isBookmarkEmpty: Bool {
        return bookmarks.isEmpty
    }
}
