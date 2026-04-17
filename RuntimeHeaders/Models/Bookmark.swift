//
//  Bookmark.swift
//  HeaderViewer
    

import Foundation


struct Bookmark {
    let name: String
    let parentPath: String
    let date: Date
    
    var lastPathComponent: Substring {
        parentPath.split(separator: "/").last!
    }
}

extension Bookmark: Identifiable, Equatable, Codable {
    var id: String { "\(parentPath)/\(name)" }

    static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
        lhs.name == rhs.name && lhs.parentPath == rhs.parentPath
    }
}

struct BookmarkFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let date: Date
    var bookmarks: [Bookmark]
    
    init(id: UUID = UUID(), name: String, date: Date = .now, bookmarks: [Bookmark] = []) {
        self.id = id
        self.name = name
        self.date = date
        self.bookmarks = bookmarks
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case date
        case bookmarks
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        bookmarks = try container.decodeIfPresent([Bookmark].self, forKey: .bookmarks) ?? []
    }
}
