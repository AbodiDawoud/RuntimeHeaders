//
//  MethodInvocationArgumentsView.swift
//  RuntimeHeaders
    

import SwiftUI


struct MethodInvocationArgumentsView: View {
    let method: InspectableMethod
    let onInvoke: ([RuntimeInvocationArgument]) -> Void
    let makeCompletionHandler: (RuntimeCompletionHandlerSignature) -> RuntimeInvocationArgument

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [MethodArgumentDraft]

    init(
        method: InspectableMethod,
        onInvoke: @escaping ([RuntimeInvocationArgument]) -> Void,
        makeCompletionHandler: @escaping (RuntimeCompletionHandlerSignature) -> RuntimeInvocationArgument
    ) {
        self.method = method
        self.onInvoke = onInvoke
        self.makeCompletionHandler = makeCompletionHandler
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
                        guard let arguments = buildArguments() else { return }
                        onInvoke(arguments)
                        dismiss()
                    }
                    .disabled(canBuildArguments == false)
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
            case .completionHandler:
                Picker("Signature", selection: draft.completionHandlerSignature) {
                    ForEach(RuntimeCompletionHandlerSignature.allCases) { signature in
                        Text(signature.displayName).tag(signature)
                    }
                }
            case .unsupported:
                Text("Unsupported type \(draft.wrappedValue.argument.typeEncoding)")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var canBuildArguments: Bool {
        drafts.allSatisfy(canBuildArgument(for:))
    }

    private func buildArguments() -> [RuntimeInvocationArgument]? {
        guard canBuildArguments else { return nil }
        return drafts.compactMap(runtimeArgument(for:))
    }

    private func canBuildArgument(for draft: MethodArgumentDraft) -> Bool {
        let trimmedText = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch draft.argument.kind {
        case .bool, .string, .completionHandler:
            return true
        case .integer:
            return Int(trimmedText) != nil
        case .unsignedInteger:
            return UInt(trimmedText) != nil
        case .floatingPoint:
            return Double(trimmedText) != nil
        case .unsupported:
            return false
        }
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
        case .completionHandler:
            return makeCompletionHandler(draft.completionHandlerSignature)
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
    var completionHandlerSignature: RuntimeCompletionHandlerSignature

    init(argument: InspectableMethodArgument) {
        self.argument = argument
        text = ""
        boolValue = false
        completionHandlerSignature = .object
    }

    var id: Int {
        argument.id
    }
}
