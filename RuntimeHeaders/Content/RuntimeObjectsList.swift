//
//  RuntimeObjectsView.swift
//  HeaderViewer

import SwiftUI


struct RuntimeObjectsList: View {
    let runtimeObjects: [RuntimeObjectType] // caller's responsibility to filter this
    
    @EnvironmentObject private var navigation: AppNavigation
    @Binding var searchString: String
    @Binding var searchScope: RuntimeTypeSearchScope
    
    
    var body: some View {
        List(runtimeObjects, selection: $navigation.selectedObject) {
            RuntimeObjectRow(type: $0)
        }
        .id(runtimeObjects) // don't try to diff the List
        .searchable(
            text: $searchString,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .autocorrectionDisabled()
        .scrollDismissesKeyboard(.immediately)
        .searchScopes($searchScope) {
            Text("All")
                .tag(RuntimeTypeSearchScope.all)
            Text("Classes")
                .tag(RuntimeTypeSearchScope.classes)
            Text("Protocols")
                .tag(RuntimeTypeSearchScope.protocols)
        }
    }
}
