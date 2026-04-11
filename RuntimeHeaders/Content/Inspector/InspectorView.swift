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
    @State private var includePrivateMethods: Bool = true
    @State private var includeArgumentMethods: Bool = true
    @State private var allowSafetyFilteredMethods: Bool = true
    @State private var selectedArgumentMethod: InspectableMethod?

    init(resolvedInstance: ResolvedRuntimeInstance) {
        _viewModel = StateObject(wrappedValue: RuntimeObjectInspectorViewModel(resolvedInstance: resolvedInstance))
    }

    
    var body: some View {
        NavigationStack {
            List {
                Section(viewModel.resolvedInstance.subjectDescription) {
                    inspectorRow("Resolved Class", value: viewModel.resolvedInstance.className)
                    inspectorRow(viewModel.isInspectingClass ? "Runtime Class" : "Live Type", value: viewModel.resolvedInstance.displayName)
                    inspectorRow("Acquired Via", value: viewModel.resolvedInstance.acquisitionDescription)
                    if let pointerDescription = viewModel.resolvedInstance.pointerDescription {
                        inspectorRow("Pointer", value: pointerDescription)
                    }
                }

                Section(viewModel.isInspectingClass ? "Static Values" : "Properties") {
                    if filteredProperties.isEmpty {
                        Text("No properties match the current filters.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredProperties) { property in
                            Button {
                                viewModel.read(property)
                            } label: {
                                propertyRow(property)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section(viewModel.isInspectingClass ? "Callable Class Methods" : callableMethodsSectionTitle) {
                    if filteredMethods.isEmpty {
                        Text("No methods match the current filters.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredMethods) { method in
                            Group {
                                if canInvoke(method) {
                                    Button {
                                        if method.argumentCount > 0 {
                                            selectedArgumentMethod = method
                                        } else {
                                            viewModel.invoke(method)
                                        }
                                    } label: {
                                        methodRow(method)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    methodRow(method)
                                }
                            }
                        }
                    }
                }

                if disabledMethods.isEmpty == false {
                    Section("Unavailable Methods") {
                        ForEach(disabledMethods) {
                            methodRow($0)
                                .opacity(0.75)
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
            .inlinedNavigationTitle(viewModel.resolvedInstance.inspectorTitle)
            .sheet(item: $selectedArgumentMethod) { method in
                MethodInvocationArgumentsView(method: method) { arguments in
                    viewModel.invoke(method, arguments: arguments)
                }
            }
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
                    Button("Refresh", systemImage: "arrow.clockwise", action: viewModel.refresh)
                        .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Include Superclass Members", isOn: $includeInheritedMembers)
                        Toggle("Include NSObject Members", isOn: $includeNSObjectMembers)
                        Toggle("Include Accessibility Members", isOn: $includeAccessibilityMembers)
                        Toggle("Include Private Methods", isOn: $includePrivateMethods)
                        Toggle("Include Methods With Arguments", isOn: $includeArgumentMethods)
                        Toggle("Allow Safety-Filtered Methods", isOn: $allowSafetyFilteredMethods)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredMethods: [InspectableMethod] {
        viewModel.methods.filter { method in
            canInvoke(method) &&
            shouldIncludeMember(
                isInherited: method.isInherited,
                isNSObjectMember: method.isNSObjectMember,
                isAccessibilityRelated: method.isAccessibilityRelated,
                isPrivateMethod: method.isPrivateMethod,
                hasArguments: method.argumentCount > 0
            )
        }
    }

    private var callableMethodsSectionTitle: String {
        allowSafetyFilteredMethods ? "Callable Methods" : "Safe Methods"
    }

    private var disabledMethods: [InspectableMethod] {
        viewModel.methods.filter { method in
            canInvoke(method) == false &&
            shouldIncludeMember(
                isInherited: method.isInherited,
                isNSObjectMember: method.isNSObjectMember,
                isAccessibilityRelated: method.isAccessibilityRelated,
                isPrivateMethod: method.isPrivateMethod,
                hasArguments: method.argumentCount > 0
            )
        }
    }

    private func canInvoke(_ method: InspectableMethod) -> Bool {
        method.isSafeToInvoke || (allowSafetyFilteredMethods && method.isBlockedBySafetyFilter)
    }

    private func shouldIncludeMember(
        isInherited: Bool,
        isNSObjectMember: Bool,
        isAccessibilityRelated: Bool,
        isPrivateMethod: Bool = false,
        hasArguments: Bool = false
    ) -> Bool {
        if includeArgumentMethods == false && hasArguments {
            return false
        }
        if includePrivateMethods == false && isPrivateMethod {
            return false
        }
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

    private var filteredProperties: [InspectableProperty] {
        viewModel.properties.filter { property in
            shouldIncludeMember(
                isInherited: property.isInherited,
                isNSObjectMember: property.isNSObjectMember,
                isAccessibilityRelated: property.isAccessibilityRelated
            )
        }
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

                Text(property.isDirectIvar ? "Direct ivar" : "")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if property.isValueLoaded == false {
                Text("Tap to read")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else if let errorMessage = property.errorMessage {
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
                    .foregroundColor(canInvoke(method) ? .secondary : .orange)
            }

            Spacer(minLength: 12)

            Image(systemName: canInvoke(method) ? "play.circle.fill" : "lock.circle")
                .foregroundStyle(canInvoke(method) ? .blue : .secondary)
        }
        .padding(.vertical, 2)
    }

    private func methodSubtitle(for method: InspectableMethod) -> String {
        if allowSafetyFilteredMethods && method.isBlockedBySafetyFilter {
            return "Safety filter disabled"
        }
        if let blockedReason = method.invocationBlockedReason {
            return blockedReason
        }
        if method.returnKind == .void {
            return method.argumentCount > 0 ? "\(method.argumentCount) argument\(method.argumentCount == 1 ? "" : "s")" : (method.isClassMethod ? "Class action" : "Action")
        }
        if method.argumentCount > 0 {
            return "\(method.argumentCount) argument\(method.argumentCount == 1 ? "" : "s") -> \(method.returnTypeEncoding)"
        }
        return "Returns \(method.returnTypeEncoding)"
    }
}

private extension InspectableMethod {
    var isBlockedBySafetyFilter: Bool {
        invocationBlockedReason == "Blocked by safety filter"
    }
}
