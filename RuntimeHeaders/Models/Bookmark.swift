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

extension Bookmark: Identifiable {
    var id: String { name }
}

extension Bookmark: Codable, Equatable {}
