//
//  HistoryManager.swift
//  HeaderViewer
    

import Foundation


final class HistoryManager: ObservableObject {
    @Published var historyItems: [HistoryItem] = []
    
    private let defaults = UserDefaults.standard
    private let key = "objectsHistory"
    
    
    var historyCount: Int { historyItems.count }
    var isHistoryEmpty: Bool { historyItems.isEmpty }
    
    init() {
        loadHistory()
    }
    
    
    func addObject(_ newObject: RuntimeObjectType?) {
        let isAlreadyInHistory = historyItems.contains { $0.object == newObject }
        guard let newObject, !isAlreadyInHistory else { return }
        
        
        let newItem = HistoryItem(object: newObject, parentPath: LastNodeTracker.path, seenAt: .now)
        

        let limit = PreferenceController.shared.preferences.historyLimit
        if limit != 0, historyItems.count >= limit {
            historyItems = Array(historyItems.prefix(limit - 1))
        }

        historyItems.insert(newItem, at: 0)
        syncHistory()
    }
    
    func removeObject(_ item: HistoryItem) {
        historyItems.removeAll { $0 == item }
        syncHistory()
    }
    
    func removeObject(_ indexSet: IndexSet) {
        for index in indexSet.sorted(by: >) {
            historyItems.remove(at: index)
        }

        syncHistory()
    }
    
    func refreshHistory() {
        loadHistory()
    }
    
    func clearHistory() {
        if isHistoryEmpty { return }

        historyItems.removeAll()
        defaults.removeObject(forKey: key)
    }
    
    
    private func syncHistory() {
        let data = try? JSONEncoder().encode(historyItems)
        defaults.set(data, forKey: key)
    }
    
    private func loadHistory() {
        historyItems = enforceLimit(on: restoreHistoryData())
    }
    
    private func restoreHistoryData() -> [HistoryItem] {
        guard let data = defaults.data(forKey: key)
        else { return [] }

        if let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            return items
        }

        guard let objects = try? JSONDecoder().decode([RuntimeObjectType].self, from: data) else { return [] }
        return objects.map { HistoryItem(object: $0, parentPath: nil, seenAt: .now) }
    }
    
    private func enforceLimit(on history: [HistoryItem]) -> [HistoryItem] {
        let limit = PreferenceController.shared.preferences.historyLimit
        guard limit != 0 else { return history }
        return Array(history.prefix(limit))
    }
}
