//
//  ActivityController.swift
//  RuntimeHeaders
    

import UIKit

class ActivityControllerPresenter {
    /// Public API to present UIActivityViewController on temporary new window to avoid the key window if it's already presenting some sheets or covers.
    static func present(with items: [Any], completion: UIActivityViewController.CompletionWithItemsHandler? = nil) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        window.windowLevel = .alert + 1
        
        // an temporary view controller to present the activity view controller
        let tempViewController = UIViewController()
        tempViewController.view.backgroundColor = .clear
        window.rootViewController = tempViewController
        window.makeKeyAndVisible()
        
        
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            // kill the window after completion
            window.isHidden = true
            window.rootViewController = nil
            completion?(activityType, completed, returnedItems, error)
        }
        
        
        tempViewController.present(activityViewController, animated: true)
    }
}
