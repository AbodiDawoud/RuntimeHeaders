//
//  HistoryManager.swift
//  HeaderViewer
    

import Foundation


final class HistoryManager: ObservableObject {
    @Published var historyItems: [RuntimeObjectType] = []
    
    private let defaults = UserDefaults.standard
    private let key = "objectsHistory"
    
    
    var historyCount: Int { historyItems.count }
    var isHistoryEmpty: Bool { historyItems.isEmpty }
    
    init() {
        loadHistory()
    }
    
    
    func addObject(_ newObject: RuntimeObjectType?) {
        guard let newObject else { return }
        guard !historyItems.contains(newObject) else { return }

        var updatedHistory = historyItems
        let limit = PreferenceController.shared.preferences.historyLimit
        if limit != 0, updatedHistory.count >= limit {
            updatedHistory = Array(updatedHistory.prefix(limit - 1))
        }

        updatedHistory.insert(newObject, at: 0)
        historyItems = updatedHistory
        syncHistory()
    }
    
    func removeObject(_ object: RuntimeObjectType) {
        historyItems.removeAll { $0 == object }
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
    
    private func restoreHistoryData() -> [RuntimeObjectType] {
        guard let data = defaults.data(forKey: key),
              let objects = try? JSONDecoder().decode([RuntimeObjectType].self, from: data)
        else { return [] }
        
        return objects
    }
    
    private func enforceLimit(on history: [RuntimeObjectType]) -> [RuntimeObjectType] {
        let limit = PreferenceController.shared.preferences.historyLimit
        guard limit != 0 else { return history }
        return Array(history.prefix(limit))
    }
}
