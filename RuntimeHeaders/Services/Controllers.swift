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


class FileExportCoordinator: NSObject, UIDocumentPickerDelegate {
    private var exportWindow: UIWindow?
    static let shared = FileExportCoordinator()
    
    func export(to url: URL) {
        let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        exportWindow = UIWindow(windowScene: scene)
        exportWindow!.windowLevel = .alert + 1
        
        let documentPicker = UIDocumentPickerViewController(forExporting: [url])
        documentPicker.delegate = self
        
        let viewController = UIViewController()
        viewController.view.backgroundColor = .clear
        exportWindow!.rootViewController = viewController
        exportWindow!.makeKeyAndVisible()
        viewController.present(documentPicker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.dismiss(animated: true)
        exportWindow?.rootViewController = nil
        exportWindow = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
        exportWindow?.rootViewController = nil
        exportWindow = nil
    }
}
