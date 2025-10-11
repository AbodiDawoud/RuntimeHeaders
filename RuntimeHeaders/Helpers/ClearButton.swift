//
//  ClearButton.swift
//  HeaderViewer


import SwiftUI

// Clear button with confirmation
struct ClearButton: ToolbarContent {
    @State private var showConfirmation: Bool = false
    
    var tint: Color = .secondary
    var placement: ToolbarItemPlacement = .primaryAction
    let action: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            Button(action: { showConfirmation.toggle() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .confirmationDialog("", isPresented: $showConfirmation) {
                Button("Clear", role: .destructive, action: action)
            }
        }
    }
}
