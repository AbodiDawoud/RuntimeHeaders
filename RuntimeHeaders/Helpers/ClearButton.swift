//
//  ClearButton.swift
//  HeaderViewer


import SwiftUI

// Clear button with confirmation
struct ClearButton: ToolbarContent {
    @State private var showConfirmation: Bool = false
    @Environment(\.colorScheme) private var scheme
    
    var tint: Color = .secondary
    var placement: ToolbarItemPlacement = .primaryAction
    let action: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            Button(action: { showConfirmation.toggle() }) {
                Text("Clear")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(tint.gradient)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .stroke(Color.pink.opacity(0.06), lineWidth: 0.9)
                            .fill(tint.quinary.opacity(scheme == .light ? 0.4 : 0.95))
                    )
            }
            .buttonStyle(.plain)
            .confirmationDialog("", isPresented: $showConfirmation) {
                Button("Clear", role: .destructive, action: action)
            }
        }
    }
}
