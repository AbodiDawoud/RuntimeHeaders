//
//  HistoryItem.swift
//  RuntimeHeaders
    

import Foundation


struct HistoryItem: Identifiable, Codable, Equatable {
    var object: RuntimeObjectType
    var parentPath: String?
    var seenAt: Date
    
    var id: String {
        "\(object.name)|\(String(describing: parentPath))"
    }
    
    var lastPathComponent: Substring? {
        parentPath?.split(separator: "/").last
    }
}
