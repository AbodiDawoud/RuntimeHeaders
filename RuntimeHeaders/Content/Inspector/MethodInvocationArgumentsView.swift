//
//  MethodInvocationArgumentsView.swift
//  RuntimeHeaders
    

import SwiftUI


struct MethodInvocationArgumentsView: View {
    let method: InspectableMethod
    let onInvoke: ([RuntimeInvocationArgument]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [MethodArgumentDraft]

    init(method: InspectableMethod, onInvoke: @escaping ([RuntimeInvocationArgument]) -> Void) {
        self.method = method
        self.onInvoke = onInvoke
        _drafts = State(initialValue: method.arguments.map(MethodArgumentDraft.init(argument:)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Method") {
                    Text(method.selectorName)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section("Arguments") {
                    ForEach($drafts) { $draft in
                        argumentInput(draft: $draft)
                    }
                }
            }
            .inlinedNavigationTitle("Run Method")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Run") {
                        guard let arguments = parsedArguments else { return }
                        onInvoke(arguments)
                        dismiss()
                    }
                    .disabled(parsedArguments == nil)
                }
            }
        }
    }

    @ViewBuilder
    private func argumentInput(draft: Binding<MethodArgumentDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(argumentTitle(for: draft.wrappedValue.argument))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            switch draft.wrappedValue.argument.kind {
            case .bool:
                Toggle("Value", isOn: draft.boolValue)
            case .integer:
                TextField("Integer", text: draft.text)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
            case .unsignedInteger:
                TextField("Unsigned integer", text: draft.text)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
            case .floatingPoint:
                TextField("Double", text: draft.text)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
            case .string:
                TextField("String", text: draft.text)
                    .textInputAutocapitalization(.never)
            case .unsupported:
                Text("Unsupported type \(draft.wrappedValue.argument.typeEncoding)")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var parsedArguments: [RuntimeInvocationArgument]? {
        drafts.map(runtimeArgument(for:)).allSatisfy { $0 != nil }
            ? drafts.compactMap(runtimeArgument(for:))
            : nil
    }

    private func runtimeArgument(for draft: MethodArgumentDraft) -> RuntimeInvocationArgument? {
        let trimmedText = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch draft.argument.kind {
        case .bool:
            return .bool(draft.boolValue)
        case .integer:
            guard let value = Int(trimmedText) else { return nil }
            return .integer(value)
        case .unsignedInteger:
            guard let value = UInt(trimmedText) else { return nil }
            return .unsignedInteger(value)
        case .floatingPoint:
            guard let value = Double(trimmedText) else { return nil }
            return .double(value)
        case .string:
            return .string(draft.text)
        case .unsupported:
            return nil
        }
    }

    private func argumentTitle(for argument: InspectableMethodArgument) -> String {
        let selectorPieces = method.selectorName.split(separator: ":", omittingEmptySubsequences: false)
        let label: String
        if argument.index < selectorPieces.count {
            label = String(selectorPieces[argument.index])
        } else {
            label = argument.displayName
        }

        return "\(label) (\(argument.typeEncoding))"
    }
}

private struct MethodArgumentDraft: Identifiable {
    let argument: InspectableMethodArgument
    var text: String
    var boolValue: Bool

    init(argument: InspectableMethodArgument) {
        self.argument = argument
        text = ""
        boolValue = false
    }

    var id: Int {
        argument.id
    }
}
