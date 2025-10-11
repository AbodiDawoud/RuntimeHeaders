//
//  HistoryManager.swift
//  HeaderViewer
    

import Foundation


class HistoryManager: ObservableObject {
    @Published var historyItems: [RuntimeObjectType] = []
    
    private let defaults = UserDefaults.standard
    private let key = "objectsHistory"
    
    
    var historyCount: Int { historyItems.count }
    var isHistoryEmpty: Bool { historyItems.isEmpty }
    
    init() {
        refreshHistory()
    }
    
    
    func addObject(_ newObject: RuntimeObjectType?) {
        guard let newObject else { return }
        
        // Get all previous history objects, to append new item.
        var previousData = restoreHistoryData()
        
        
        if previousData.isEmpty {
            // Saving for first time, no previous data.
            let objectToSave: [RuntimeObjectType] = [newObject]
            let encodedData = try! JSONEncoder().encode(objectToSave)
            
            defaults.setValue(encodedData, forKey: key)
            historyItems.append(contentsOf: objectToSave)
            
            return
        }
        
        // The item is already exists, skip it.
        if previousData.contains(newObject) { return }
        
        
        // If no more size for the new object, remove the oldest object and insert the new object at the first index
        let limit = SettingsManager.shared.preferences.historyLimit
        if previousData.count >= limit && limit != 0 {
            let oldestObjectIndex = previousData.endIndex - 1
            historyItems.remove(at: oldestObjectIndex)
            previousData.remove(at: oldestObjectIndex)
        }


        
        historyItems.insert(newObject, at: 0)
        previousData.insert(newObject, at: 0)
        
        
        // Encode the data and save it to user defaults.
        let encodedObjects = try! JSONEncoder().encode(previousData)
        defaults.setValue(encodedObjects, forKey: key)
    }
    
    func removeObject(_ object: RuntimeObjectType) {
        let previousData = restoreHistoryData()
        historyItems.removeAll { $0 == object }
        
        
        let newData = previousData.filter { $0 != object }
        let encodedData = try! JSONEncoder().encode(newData)
        defaults.set(encodedData, forKey: key)
    }
    
    func removeObject(_ indexSet: IndexSet) {
        var previousData = restoreHistoryData()
        
        for index in indexSet {
            historyItems.remove(at: index)
            previousData.remove(at: index)
            
            let encodedObjs = try! JSONEncoder().encode(previousData)
            defaults.set(encodedObjs, forKey: key)
        }
    }
    
    func refreshHistory() {
        self.historyItems = restoreHistoryData()
    }
    
    func clearHistory() {
        if isHistoryEmpty { return }

        historyItems.removeAll()
        defaults.removeObject(forKey: key)
    }
    
    
    private func restoreHistoryData() -> [RuntimeObjectType] {
        guard let data = defaults.data(forKey: key),
              let objects = try? JSONDecoder().decode([RuntimeObjectType].self, from: data)
        else { return [] }
        
        return objects
    }
}
