//
//  RuntimeSelectorChooserView.swift
//  RuntimeHeaders
    

import SwiftUI

struct RuntimeSelectorChooserView: View {
    let className: String
    let selectorCandidates: [RuntimeInstanceCandidate]
    let onSelect: (RuntimeInstanceCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var customSelectorName: String = ""
    @State private var customSelectorError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Detected Class Getters") {
                    ForEach(filteredCandidates) { candidate in
                        Button {
                            submit(candidate)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.displayName)
                                    .font(.headline)
                                Text(candidate.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Custom Selector") {
                    TextField("sharedInstance", text: $customSelectorName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Try Selector", systemImage: "play.fill", action: submitCustomSelector)
                        .buttonStyle(.plain)
                        .imageScale(.small)
                        .disabled(trimmedCustomSelector.isEmpty)
                }
                
                if let customSelectorError {
                    Section {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.pink)
                                .imageScale(.large)
                                .symbolRenderingMode(.hierarchical)
                            
                            Text(customSelectorError)
                        }
                    } header: {
                        HStack {
                            Text("Error")
                            Spacer()
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.large)
                                .symbolVariant(.circle.fill)
                                .symbolRenderingMode(.hierarchical)
                                .onTapGesture {
                                    hapticFeedback(.light)
                                    self.customSelectorError = nil
                                }
                        }
                    }
                }
            }
            .navigationTitle("Live Object Getter")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredCandidates: [RuntimeInstanceCandidate] {
        if searchText.isEmpty { return selectorCandidates }
        return selectorCandidates.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.selectorName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var trimmedCustomSelector: String {
        customSelectorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedCustomSelector: String {
        let trimmedName = trimmedCustomSelector
        if trimmedName.hasSuffix("()") {
            return String(trimmedName.dropLast(2))
        }
        return trimmedName
    }

    private func submit(_ candidate: RuntimeInstanceCandidate) {
        dismiss()
        onSelect(candidate)
    }

    private func submitCustomSelector() {
        let selectorName = normalizedCustomSelector
        guard selectorName.isEmpty == false else { return }
        if let errorMessage = RuntimeInstanceResolver.customClassGetterValidationError(
            className: className,
            selectorName: selectorName
        ) {
            customSelectorError = errorMessage
            return
        }

        let candidate = RuntimeInstanceCandidate(
            selectorName: selectorName,
            displayName: selectorName,
            subtitle: "Custom zero-argument class getter",
            kind: .classGetter
        )
        dismiss()
        onSelect(candidate)
    }
}

struct RuntimeSelectorChooserState: Identifiable {
    let className: String
    let selectorCandidates: [RuntimeInstanceCandidate]

    var id: String { className }
}
