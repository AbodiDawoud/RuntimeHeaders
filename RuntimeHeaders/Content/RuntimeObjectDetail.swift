//
//  RuntimeObjectDetail.swift
//  HeaderViewer


import SwiftUI
import ObjectiveC
import ClassDumpRuntime


struct RuntimeObjectDetail: View {
    private let type: RuntimeObjectType
    
    @SceneStorage("stripProtocolConformance") private var stripProtocolConformance: Bool = false
    @SceneStorage("stripOverrides") private var stripOverrides: Bool = false
    @SceneStorage("stripDuplicates") private var stripDuplicates: Bool = true
    @SceneStorage("stripSynthesized") private var stripSynthesized: Bool = true
    @SceneStorage("addSymbolImageComments") private var addSymbolImageComments: Bool = false
    
    @State private var showCodeAppearanceCover: Bool = false
    
    init(type: RuntimeObjectType, parentPath: String? = nil) {
        self.type = type
        
        guard let parentPath else { print("not valid parent path"); return }
        let isLoaded = RuntimeListings.shared.isImageLoaded(path: parentPath)
        
        if isLoaded == false {
            do {
                try CDUtilities.loadImage(at: parentPath)
                print("Loaded framework: \(parentPath)")
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Image not loaded for bookmark parent: \(String(describing: parentPath))")
            print("Framework Path: \(parentPath), Is Loaded: \(isLoaded)")
        }
    }
    
    private var generationOptions: CDGenerationOptions {
        let options: CDGenerationOptions = .init()
        options.stripProtocolConformance = stripProtocolConformance
        options.stripOverrides = stripOverrides
        options.stripDuplicates = stripDuplicates
        options.stripSynthesized = stripSynthesized
        options.stripCtorMethod = true
        options.stripDtorMethod = true
        options.addSymbolImageComments = addSymbolImageComments
        return options
    }
    
    
    var body: some View {
        Group {
            switch type {
            case .class(let name):
                if let cls = NSClassFromString(name) {
                    let semanticString: CDSemanticString = CDClassModel(with: cls).semanticLines(with: generationOptions)
                    
                    SemanticStringView(semanticString, fileName: name)
                } else {
                    ImageNotFoundView(imageName: name)
                }
                
            case .protocol(let name):
                if let prtcl = NSProtocolFromString(name) {
                    let semanticString: CDSemanticString = CDProtocolModel(with: prtcl).semanticLines(with: generationOptions)
                    
                    SemanticStringView(semanticString, fileName: name)
                } else {
                    ImageNotFoundView(imageName: name)
                }
            }
        }
        .inlinedNavigationTitle(type.name)
        .fullScreenCover(isPresented: $showCodeAppearanceCover, content: CodeAppearanceView.init)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    FontToolbarItem()
                    Divider()
                    Toggle("Strip protocol conformance", isOn: $stripProtocolConformance)
                    Toggle("Strip overrides", isOn: $stripOverrides)
                    Toggle("Strip duplicates", isOn: $stripDuplicates)
                    Toggle("Strip synthesized", isOn: $stripSynthesized)
                    Toggle("Add symbol comments", isOn: $addSymbolImageComments)
                    Divider()
                    Button("Code Appearance") { showCodeAppearanceCover.toggle() }
                } label: {
                    Image(systemName: "gearshape.arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
    }
}



fileprivate struct FontToolbarItem: View {
    @ObservedObject private var preferences = CodePreferences.shared
    
    var body: some View {
        ControlGroup("Font Size", systemImage: "textformat.size") {
            Button("Smaller", systemImage: "textformat.size.smaller") {
                guard preferences.fontSize > preferences.minFontSize else { return }
                preferences.fontSize -= 1
            }
            
            Text(preferences.fontSize.formatted(.number))
            
            Button("Larger", systemImage: "textformat.size.larger") {
                guard preferences.fontSize < preferences.maxFontSize else { return }
                preferences.fontSize += 1
            }
        }
        .controlGroupStyle(.compactMenu)
        .menuActionDismissBehavior(.disabled)
    }
}


fileprivate struct ImageNotFoundView: View {
    let imageName: String
    
    var body: some View {
        GroupBox {
            HStack(alignment: .top) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.black, .yellow)
                Text("**404**")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.bottom, 12)
            
            Text("No class or protocol named *\(imageName)* was found.")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}
