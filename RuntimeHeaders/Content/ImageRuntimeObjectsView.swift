//
//  ImageRuntimeObjectsView.swift
//  HeaderViewer


import SwiftUI
import ClassDumpRuntime


struct ImageRuntimeObjectsView: View {
    @StateObject private var viewModel: ImageRuntimeObjectsViewModel
    @Binding private var selection: RuntimeObjectType?
    
    init(namedNode: NamedNode, selection: Binding<RuntimeObjectType?>) {
        _viewModel = StateObject(wrappedValue: ImageRuntimeObjectsViewModel(namedNode: namedNode))
        _selection = selection
    }
    
    var body: some View {
        switch viewModel.loadState {
        case .notLoaded:
            ImageNotLoadedView(imageName: viewModel.imageName, loadAction: viewModel.tryLoadImage)
            
            
        case .loading:
            ProgressView()
            
            
        case .loadError(let error):
            ErrorView(imagePath: viewModel.imagePath, error: error, retryAction: viewModel.tryLoadImage)
            
            
        case .loaded:
            if viewModel.isImageEmpty {
                EmptyImageView(imageName: viewModel.imageName)
            } else {
                RuntimeObjectsList(
                    runtimeObjects: viewModel.runtimeObjects, selectedObject: $selection,
                    searchString: $viewModel.searchString, searchScope: $viewModel.searchScope
                )
                .navigationTitle(viewModel.imageName)
                .navigationBarTitleDisplayMode(.large)
            }
        }
    }
}


private struct EmptyImageView: View {
    let imageName: String
    
    var body: some View {
        GroupBox {
            HStack(alignment: .top) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, .green)
                Text("**\(imageName)** is loaded.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.bottom, 12)
            
            Text("However, this image does not contain any classes or protocols")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}


private struct ImageNotLoadedView: View {
    let imageName: String
    var loadAction: () -> Void
    
    var body: some View {
        GroupBox {
            HStack(alignment: .top) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.white, .tangerine)
                Text("**\(imageName)** needs to be loaded before browsing it's content.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
            
            Button(action: loadAction) {
                Text("Load now")
                    .fontWeight(.medium)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .tint(.tangerine)
        }
        .scenePadding()
    }
}


private struct ErrorView: View {
    let imagePath: String
    let error: Error
    let retryAction: () -> Void
    
    var errorText: String {
        if let dlOpenError = error as? DlOpenError, let errorMessage = dlOpenError.message {
            return errorMessage
        } else {
            return "An unknown error occured trying to load '\(imagePath)'"
        }
    }
    
    
    var body: some View {
        GroupBox {
            Divider()
                .padding(.horizontal, -16)
            
            Text(errorText)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            
            Button(action: retryAction) {
                Text("Retry")
                    .fontWeight(.medium)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            
        } label: {
            HStack(alignment: .top) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .red)
                Text("Failed to Load")
            }
            .padding(.bottom, 4)
        }
        .padding(16)
    }
}
