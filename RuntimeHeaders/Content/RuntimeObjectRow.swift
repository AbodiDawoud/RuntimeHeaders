//
//  RuntimeObjectRow.swift
//  HeaderViewer

import SwiftUI

struct RuntimeObjectRow: View {
    let type: RuntimeObjectType
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: type.systemImageName)
                .foregroundColor(type.iconColor)
            Text(type.name)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Copy", systemImage: "square.on.square.dashed", action: copyName)
        }
    }
    
    func copyName() {
        UIPasteboard.general.string = type.name
    }
}
