//
//  ImageRuntimeObjectsViewModel.swift
//  HeaderViewer
    

import Foundation
import ClassDumpRuntime


class ImageRuntimeObjectsViewModel: ObservableObject {
    let namedNode: NamedNode
    
    let imagePath: String
    let imageName: String
    
    let runtimeListings: RuntimeListings = .shared
    
    @Published var searchString: String
    @Published var searchScope: RuntimeTypeSearchScope
    
    @Published private(set) var classNames: [String] // not filtered
    @Published private(set) var protocolNames: [String] // not filtered
    @Published private(set) var runtimeObjects: [RuntimeObjectType] // filtered based on search
    @Published private(set) var loadState: ImageLoadState
    
    var isImageEmpty: Bool {
        return classNames.isEmpty && protocolNames.isEmpty
    }
    
    init(namedNode: NamedNode) {
        self.namedNode = namedNode
        
        let imagePath = namedNode.path
        self.imagePath = imagePath
        self.imageName = namedNode.name
        
        let classNames = CDUtilities.classNamesIn(image: imagePath)
        let protocolNames = runtimeListings.imageToProtocols[CDUtilities.patchImagePathForDyld(imagePath)] ?? []
        self.classNames = classNames
        self.protocolNames = protocolNames
        
        let searchString = ""
        let searchScope: RuntimeTypeSearchScope = .all
        
        self.searchString = searchString
        self.searchScope = searchScope
        
        self.runtimeObjects = searchScope.runtimeObjects(
            classNames: classNames, protocolNames: protocolNames,
            matching: searchString
        )
        
        self.loadState = runtimeListings.isImageLoaded(path: imagePath) ? .loaded : .notLoaded
        
        runtimeListings.$classList
            .map { _ in
                CDUtilities.classNamesIn(image: imagePath)
            }
            .assign(to: &$classNames)
        
        runtimeListings.$imageToProtocols
            .map { imageToProtocols in
                imageToProtocols[CDUtilities.patchImagePathForDyld(imagePath)] ?? []
            }
            .assign(to: &$protocolNames)
        
        let debouncedSearch = $searchString
            .debounce(for: 0.08, scheduler: RunLoop.main)
        
        $searchScope
            .combineLatest(debouncedSearch, $classNames, $protocolNames) {
                $0.runtimeObjects(
                    classNames: $2, protocolNames: $3,
                    matching: $1
                )
            }
            .assign(to: &$runtimeObjects)
        
        runtimeListings.$imageList
            .map { imageList in
                imageList.contains(CDUtilities.patchImagePathForDyld(imagePath))
            }
            .filter { $0 } // only allow isLoaded to pass through; we don't want to erase an existing state
            .map { _ in
                ImageLoadState.loaded
            }
            .assign(to: &$loadState)
    }
    
    func tryLoadImage() {
        do {
            loadState = .loading
            try CDUtilities.loadImage(at: imagePath)
            // we could set .loaded here, but there are already pipelines that will update the state
        } catch {
            loadState = .loadError(error)
        }
    }
}

enum ImageLoadState {
    case notLoaded
    case loading
    case loaded
    case loadError(Error)
}
