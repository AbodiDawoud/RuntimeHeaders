//
//  RuntimeObjectsViewModel.swift
//  HeaderViewer
    

import Foundation


class RuntimeObjectsViewModel: ObservableObject {
    let runtimeListings: RuntimeListings = .shared
    
    @Published var searchString: String
    @Published var searchScope: RuntimeTypeSearchScope
    @Published private(set) var runtimeObjects: [RuntimeObjectType] // filtered based on search
    
    
    private static func runtimeObjectsFor(classNames: [String], protocolNames: [String], searchString: String, searchScope: RuntimeTypeSearchScope) -> [RuntimeObjectType] {
        var ret: [RuntimeObjectType] = []
        if searchScope.includesClasses {
            ret += classNames.map { .class(named: $0) }
        }
        if searchScope.includesProtocols {
            ret += protocolNames.map { .protocol(named: $0) }
        }
        if searchString.isEmpty { return ret }
        return ret.filter { $0.name.localizedCaseInsensitiveContains(searchString) }
    }
    
    init() {
        let searchString = ""
        let searchScope: RuntimeTypeSearchScope = .all
        
        self.searchString = searchString
        self.searchScope = searchScope
        self.runtimeObjects = Self.runtimeObjectsFor(
            classNames: runtimeListings.classList,
            protocolNames: runtimeListings.protocolList,
            searchString: searchString,
            searchScope: searchScope
        )
        
        let debouncedSearch = $searchString.debounce(for: 0.08, scheduler: RunLoop.main)
        
        $searchScope
            .combineLatest(debouncedSearch, runtimeListings.$classList, runtimeListings.$protocolList) {
                Self.runtimeObjectsFor(
                    classNames: $2, protocolNames: $3,
                    searchString: $1, searchScope: $0
                )
            }
            .assign(to: &$runtimeObjects)
    }
}
