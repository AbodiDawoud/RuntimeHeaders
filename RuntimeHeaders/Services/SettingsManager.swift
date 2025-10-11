//
//  SettingsManager.swift
//  HeaderViewer
    

import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    private let settingsKey = "appSettings" // The used key to save user preferences in UserDefaults
    @Published var preferences: AppSettings {
        didSet { saveSettings() }
    }
    
    @AppStorage("formattedCacheSize") var cacheSize: String = ""
    
    
    init() {
        guard let savedData = defaults.data(forKey: settingsKey),
              let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: savedData)
        else {
            // When the app starts for the first time, register and then save default values
            self.preferences = Self.registerDefaultSettings()
            saveSettings()
            return
        }
        
        self.preferences = decodedSettings
    }
    
    
    private func saveSettings() {
        let encodedData = try? JSONEncoder().encode(preferences)
        defaults.set(encodedData, forKey: settingsKey)
    }
    
    private static func registerDefaultSettings() -> AppSettings {
        let settings = AppSettings(
            historyEnabled: true,
            historyBadgeEnabled: true,
            historyLimit: 0, // unlimited
            preferredColorScheme: "nil" // defaults to system
        )
        
        let encodedData = try! JSONEncoder().encode(settings)
        UserDefaults.standard.register(
            defaults: ["appSettings": encodedData]
        )
        
        return settings
    }
    
    // To be used when SettingsTab appears
    func calculateCacheSize() {
        cacheSize = formattedCacheSize()
    }
    
    func clearCache() {
        let fileManager = FileManager.default
        let cacheUrls = [
            fileManager.temporaryDirectory,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        ]
        
        for directory in cacheUrls {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                for fileURL in fileURLs {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch { return }
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        calculateCacheSize()
    }
    
    private func formattedCacheSize() -> String {
        let fileManager = FileManager.default
        let cacheUrls = [
            fileManager.temporaryDirectory,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        ]

        var totalSize: Int64 = 0
        
        for dictionary in cacheUrls {
            if let urls = try? fileManager.contentsOfDirectory(at: dictionary, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) {
                for url in urls {
                    if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        
        return formatter.string(fromByteCount: totalSize)
    }
}


struct AppSettings: Codable {
    var historyEnabled: Bool
    var historyBadgeEnabled: Bool
    var historyLimit: Int
    
    var preferredColorScheme: String
    
    
    // Converts the saved string to color scheme object
    func colorScheme() -> ColorScheme? {
        switch preferredColorScheme.lowercased() {
        case "nil": return nil // "System"
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
