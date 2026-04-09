//
//  RuntimeObjectInspectorView.swift
//  RuntimeHeaders
//

import SwiftUI

struct RuntimeObjectInspectorView: View {
    @StateObject private var viewModel: RuntimeObjectInspectorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var includeInheritedMembers: Bool = false
    @State private var includeNSObjectMembers: Bool = false
    @State private var includeAccessibilityMembers: Bool = false

    init(resolvedInstance: ResolvedRuntimeInstance) {
        _viewModel = StateObject(wrappedValue: RuntimeObjectInspectorViewModel(resolvedInstance: resolvedInstance))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Instance") {
                    inspectorRow("Resolved Class", value: viewModel.resolvedInstance.className)
                    inspectorRow("Live Type", value: viewModel.resolvedInstance.displayName)
                    inspectorRow("Singleton Selector", value: viewModel.resolvedInstance.selectorName)
                    inspectorRow("Pointer", value: viewModel.resolvedInstance.pointerDescription)
                }

                Section("Properties") {
                    if filteredProperties.isEmpty {
                        Text("No properties match the current filters.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredProperties) { property in
                            propertyRow(property)
                        }
                    }
                }

                Section("Safe Methods") {
                    if filteredMethods.isEmpty {
                        Text("No methods match the current filters.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredMethods) { method in
                            Button {
                                viewModel.invoke(method)
                            } label: {
                                methodRow(method)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let lastInvocation = viewModel.lastInvocation {
                    Section("Last Result") {
                        inspectorRow("Selector", value: lastInvocation.selectorName)
                        if let errorMessage = lastInvocation.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.system(.footnote, design: .monospaced))
                        } else {
                            Text(lastInvocation.valueDescription)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .inlinedNavigationTitle("Live Object")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        viewModel.refresh()
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Include Superclass Members", isOn: $includeInheritedMembers)
                        Toggle("Include NSObject Members", isOn: $includeNSObjectMembers)
                        Toggle("Include Accessibility Members", isOn: $includeAccessibilityMembers)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredProperties: [InspectableProperty] {
        viewModel.properties.filter { property in
            shouldIncludeMember(
                isInherited: property.isInherited,
                isNSObjectMember: property.isNSObjectMember,
                isAccessibilityRelated: property.isAccessibilityRelated
            )
        }
    }

    private var filteredMethods: [InspectableMethod] {
        viewModel.methods.filter { method in
            shouldIncludeMember(
                isInherited: method.isInherited,
                isNSObjectMember: method.isNSObjectMember,
                isAccessibilityRelated: method.isAccessibilityRelated
            )
        }
    }

    private func shouldIncludeMember(
        isInherited: Bool,
        isNSObjectMember: Bool,
        isAccessibilityRelated: Bool
    ) -> Bool {
        if includeAccessibilityMembers == false && isAccessibilityRelated {
            return false
        }
        if includeNSObjectMembers == false && isNSObjectMember {
            return false
        }
        if includeInheritedMembers == false && isInherited {
            return false
        }
        return true
    }

    private func inspectorRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private func propertyRow(_ property: InspectableProperty) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(property.name)
                        .font(.headline)
                    if property.isInherited {
                        Text(property.declaringClassName)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                Text(property.getterName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = property.errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.red)
            } else {
                Text(property.valueDescription)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 3)
    }

    private func methodRow(_ method: InspectableMethod) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(method.selectorName)
                    .font(.headline)

                if method.isInherited {
                    Text(method.declaringClassName)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(methodSubtitle(for: method))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Image(systemName: "play.circle.fill")
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 2)
    }

    private func methodSubtitle(for method: InspectableMethod) -> String {
        if method.returnKind == .void {
            return "Action"
        }
        return "Returns \(method.returnTypeEncoding)"
    }
}
