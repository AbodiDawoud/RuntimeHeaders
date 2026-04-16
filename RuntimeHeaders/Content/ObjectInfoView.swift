//
//  ObjectInfoView.swift
//  RuntimeHeaders
    

import SwiftUI

struct ObjectInformationView: View {
    @Environment(\.dismiss) private var dismiss
    private let info: RuntimeObjectInfo

    init(_ info: RuntimeObjectInfo) {
        self.info = info
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Overview") {
                    infoRow("Name", value: info.title)
                    infoRow("Kind", value: info.kind)
                    infoRow("Framework", value: info.parentFramework)
                    
                    VStack(alignment: .leading) {
                        Text("Path")
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                            .textScale(.secondary)
                            .textCase(.uppercase)
                            .font(.callout)
                        
                        Text(info.path ?? "Unknown")
                    }
                }
                
                Section("Members") {
                    //infoRow("Total Properties", value: info.totalProperties)
                    //infoRow("Total Methods", value: info.totalMethods)
                    infoRow("Ivars", value: info.ivarCount)
                    infoRow("Instance Methods", value: info.totalInstanceMethods)
                    infoRow("Class Methods", value: info.totalClassMethods)
                    infoRow("Instance Size", value: info.instanceSize.map { "\($0.formatted()) bytes" })
                    infoRow("Total Lines", value: info.totalLines.formatted())
                }

                if info.requiredInstanceMethods != nil || info.optionalInstanceMethods != nil {
                    Section("Protocol Requirements") {
                        infoRow("Required Instance Methods", value: info.requiredInstanceMethods)
                        infoRow("Optional Instance Methods", value: info.optionalInstanceMethods)
                        infoRow("Required Class Methods", value: info.requiredClassMethods)
                        infoRow("Optional Class Methods", value: info.optionalClassMethods)
                    }
                }
                
                if info.inheritance.isEmpty == false {
                    Section("Inheritance") {
                        ForEach(Array(info.inheritance.enumerated()), id: \.offset) { index, name in
                            HStack {
                                Text(index == 0 ? "Self" : "")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(name)
                                    .textSelection(.enabled)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

                if info.adoptedProtocols.isEmpty == false {
                    Section("Adopted Protocols") {
                        ForEach(info.adoptedProtocols, id: \.self) {
                            Text($0)
                        }
                    }
                }

                if info.inheritedProtocols.isEmpty == false {
                    Section("Inherited Protocols") {
                        ForEach(info.inheritedProtocols, id: \.self) {
                            Text($0)
                        }
                    }
                }
            }
            .navigationTitle("\(info.kind) Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                        .font(.callout.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func infoRow(_ title: String, value: String?) -> some View {
        LabeledContent(title) {
            Text(value?.isEmpty == false ? value! : "Unavailable")
                .foregroundStyle(value == nil ? .secondary : .primary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }

    private func infoRow(_ title: String, value: Int?) -> some View {
        infoRow(title, value: value?.formatted())
    }
}
