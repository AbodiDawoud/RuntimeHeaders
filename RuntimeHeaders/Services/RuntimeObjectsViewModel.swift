//
//  RuntimeObjectsViewModel.swift
//  HeaderViewer
    

import Foundation


class RuntimeObjectsViewModel: ObservableObject {
    let runtimeListings: RuntimeListings = .shared
    
    @Published var searchString: String
    @Published var searchScope: RuntimeTypeSearchScope
    @Published private(set) var runtimeObjects: [RuntimeObjectType] // filtered based on search
    
    init() {
        let searchString = ""
        let searchScope: RuntimeTypeSearchScope = .all
        
        self.searchString = searchString
        self.searchScope = searchScope
        self.runtimeObjects = searchScope.runtimeObjects(
            classNames: runtimeListings.classList,
            protocolNames: runtimeListings.protocolList,
            matching: searchString
        )
        
        let debouncedSearch = $searchString.debounce(for: 0.08, scheduler: RunLoop.main)
        
        $searchScope
            .combineLatest(debouncedSearch, runtimeListings.$classList, runtimeListings.$protocolList) {
                $0.runtimeObjects(
                    classNames: $2, protocolNames: $3,
                    matching: $1
                )
            }
            .assign(to: &$runtimeObjects)
    }
}
