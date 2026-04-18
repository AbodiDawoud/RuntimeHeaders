//
//  ClearButton.swift
//  HeaderViewer


import SwiftUI
import Toasts

// Clear button with confirmation
struct ClearButton: ToolbarContent {
    @State private var showConfirmation: Bool = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.presentToast) private var presentToast
    
    var tint: Color = .secondary
    var placement: ToolbarItemPlacement = .primaryAction
    var toastMessage: String = "Cleared"
    let action: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showConfirmation.toggle()
            } label: {
                Text("Clear")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(tint.gradient)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .stroke(tint.opacity(0.09), lineWidth: 0.9)
                            .fill(tint.quinary.opacity(scheme == .light ? 0.4 : 0.95))
                    )
            }
            .buttonStyle(.plain)
            .confirmationDialog("", isPresented: $showConfirmation) {
                Button("Clear", role: .destructive) {
                    action()
                    presentToast(.appToast(icon: "trash", message: toastMessage))
                }
            }
        }
    }
}
