//
//  ZoomGesturesRemoval.swift
//  HeaderViewer
    

import SwiftUI

fileprivate struct RemoveZoomDismissGestures: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        removeGestures(from: view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    private func removeGestures(from view: UIView) {
        DispatchQueue.main.async {
            if let zoomViewControllerView = viewController(view)?.view {
                zoomViewControllerView.gestureRecognizers?.removeAll {
                    ($0.name ?? "").contains("ZoomInteractive")
                }
            }
        }
    }
    
    func viewController(_ view: UIView) -> UIViewController? {
        sequence(first: view) { $0.next }
            .compactMap({ $0 as? UIViewController })
            .first
    }
}

extension View {
    func disableZoomInteractiveDismiiss() -> some View {
        self.background(RemoveZoomDismissGestures())
    }
}
