//
//  HistoryItem.swift
//  RuntimeHeaders
    

import Foundation


struct HistoryItem: Identifiable, Codable, Equatable {
    let name: String
    let parentPath: String
    let date: Date
    
    var id: String { name }
    
    var lastPathComponent: Substring {
        parentPath.split(separator: "/").last!
    }
}
