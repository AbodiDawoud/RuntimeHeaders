//
//  RuntimeObjectRow.swift
//  HeaderViewer

import SwiftUI
import Toasts

struct RuntimeObjectRow: View {
    let type: RuntimeObjectType
    @Environment(\.presentToast) private var presentToast
    
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
        presentToast(ToastValue(message: "Copied \(type.name)"))
    }
}
