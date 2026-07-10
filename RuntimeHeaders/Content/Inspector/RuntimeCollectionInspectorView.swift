//
//  RuntimeCollectionInspectorView.swift
//  RuntimeHeaders
//

import SwiftUI
import Toasts

struct RuntimeCollectionInspectorView: View {
    let collection: InspectableCollectionReference

    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    @State private var presentedSheet: CollectionInspectorSheet?

    var body: some View {
        NavigationStack {
            List {
                Section("Collection") {
                    inspectorRow("Kind", value: collection.kind)
                    inspectorRow("Count", value: "\(collection.totalCount)")
                    inspectorRow("Acquired Via", value: collection.acquisitionDescription)
                    inspectorRow("Pointer", value: collection.objectReference.pointerDescription)

                    Button {
                        presentedSheet = .object(collection.objectReference)
                    } label: {
                        Label("Inspect Collection Object", systemImage: "shippingbox")
                    }
                }

                Section("Entries") {
                    if collection.entries.isEmpty {
                        Text("No entries.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(collection.entries) { entry in
                            collectionEntryRow(entry)
                        }

                        if collection.isTruncated {
                            Text("Showing first \(collection.entries.count) of \(collection.totalCount) entries.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .inlinedNavigationTitle(collection.displayName)
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .collection(let collection):
                    RuntimeCollectionInspectorView(collection: collection)
                case .object(let reference):
                    RuntimeObjectInspectorView(resolvedInstance: reference.resolvedInstance)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func inspectorRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
                .textScale(.secondary)
                .font(.footnote.weight(.medium))
                .textCase(.uppercase)

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private func collectionEntryRow(_ entry: InspectableCollectionEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.title)
                .font(.headline)

            ForEach(entry.values) { value in
                collectionValueRow(value)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func collectionValueRow(_ value: InspectableCollectionValue) -> some View {
        if value.isDrillable {
            Button {
                open(value)
            } label: {
                collectionValueContent(value)
            }
            .buttonStyle(.plain)
        } else {
            collectionValueContent(value)
                .contextMenu {
                    Button("Copy") {
                        copy(value.valueDescription)
                    }
                }
        }
    }

    private func collectionValueContent(_ value: InspectableCollectionValue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(value.role)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(value.valueDescription)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            if value.collectionReference != nil {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.blue)
            } else if value.objectReference != nil {
                Image(systemName: "chevron.forward.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }

    private func open(_ value: InspectableCollectionValue) {
        if let collectionReference = value.collectionReference {
            presentedSheet = .collection(collectionReference)
        } else if let objectReference = value.objectReference {
            presentedSheet = .object(objectReference)
        }
    }

    private func copy(_ value: String) {
        UIPasteboard.general.string = value
        presentToast(.init(message: "Copied value"))
    }
}

private enum CollectionInspectorSheet: Identifiable {
    case collection(InspectableCollectionReference)
    case object(InspectableObjectReference)

    var id: String {
        switch self {
        case .collection(let collection):
            return "collection:\(collection.id)"
        case .object(let reference):
            return "object:\(reference.id)"
        }
    }
}
