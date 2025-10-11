//
//  BookmarksList.swift
//  HeaderViewer
    

import SwiftUI
import ClassDumpRuntime


struct BookmarkListingView: View {
    @ObservedObject var manager = BookmarkManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var refreshId: UUID?
    
    var body: some View {
        NavigationStack {
            List {
                if manager.isBookmarkEmpty {
                    Label("No Bookmarks Yet", systemImage: "clock.arrow.circlepath")
                        .labelStyle(EmptyStatusLabelStyle(.blue, info: "Bookmark new objects to see them here."))
                } else {
                    Section("^[\(manager.bookmarks.count) Bookmark](inflect: true)") {
                        ForEach(manager.bookmarks) {
                            bookmarkRow($0)
                        }
                        .onDelete(perform: manager.removeBookmark)
                    }
                }
            }
            .inlinedNavigationTitle("Bookmarks")
            .animation(.default, value: manager.bookmarks)
            .toolbar {
                if !manager.isBookmarkEmpty {
                    ClearButton(tint: .pink, placement: .topBarTrailing, action: manager.clearBookmarks)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    func bookmarkRow(_ bookmark: Bookmark) -> some View {
        NavigationLink {
            // TODO: Bookmarks is only valid for classes for now, protocols will show empty view
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
                Divider()
                Button("Un-Bookmark", systemImage: "bookmark.slash") { removeBookmark(bookmark) }
            }
        }
    }
    
    func copy(_ str: String) {
        UIPasteboard.general.string = str
    }
    
    func searchOnSafari(_ fileName: String) {
        let url = URL(string: "https://google.com/search?q=\(fileName)")!
        UIApplication.shared.open(url)
    }
    
    func removeBookmark(_ bm: Bookmark) {
        manager.removeBookmark(for: bm)
    }
}

#Preview {
    @State @Previewable var bookmarks: [Bookmark] = [
        .init(name: "UIDevice", parentPath: "UIKit.framework", date: .now),
        .init(name: "NSObject", parentPath: "Foundation.framework", date: .now),
        .init(name: "UIViewController", parentPath: "UIKit.framework", date: .now),
        .init(name: "UIView", parentPath: "UIKit.framework", date: .now),
    ]

    NavigationStack {
        BookmarkListingView()
            .onAppear {
                BookmarkManager.shared.bookmarks = bookmarks
            }
    }
}
