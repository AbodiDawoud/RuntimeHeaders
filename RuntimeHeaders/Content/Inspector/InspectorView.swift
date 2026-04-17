//
//  RuntimeObjectInspectorView.swift
//  RuntimeHeaders
//

import SwiftUI
import Toasts

struct RuntimeObjectInspectorView: View {
    @StateObject private var viewModel: RuntimeObjectInspectorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.presentToast) private var presentToast
    
    @State private var includeInheritedMembers: Bool = false
    @State private var includeNSObjectMembers: Bool = false
    @State private var includeAccessibilityMembers: Bool = false
    @State private var includeArgumentMethods: Bool = false
    @State private var includePrivateMethods: Bool = true
    @State private var allowSafetyFilteredMethods: Bool = true
    @State private var searchText: String = ""
    @State private var selectedArgumentMethod: InspectableMethod?

    init(resolvedInstance: ResolvedRuntimeInstance) {
        _viewModel = StateObject(wrappedValue: RuntimeObjectInspectorViewModel(resolvedInstance: resolvedInstance))
    }

    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    inspectorRow("Resolved Class", value: viewModel.resolvedInstance.className)
                    inspectorRow(viewModel.isInspectingClass ? "Runtime Class" : "Live Type", value: viewModel.resolvedInstance.displayName)
                    inspectorRow("Acquired Via", value: viewModel.resolvedInstance.acquisitionDescription)
                    if let pointerDescription = viewModel.resolvedInstance.pointerDescription {
                        inspectorRow("Pointer", value: pointerDescription)
                    }
                }

                Section(viewModel.isInspectingClass ? "Static Values" : "Properties") {
                    let properties = filteredProperties
                    if properties.isEmpty {
                        Text("No properties match the current filters.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(properties) {
                            propertyRow($0)
                        }
                    }
                }

                Section(viewModel.isInspectingClass ? "Callable Class Methods" : callableMethodsSectionTitle) {
                    if filteredMethods.isEmpty {
                        Text("No methods match the current filters.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredMethods) { method in
                            if canInvoke(method) {
                                Button {
                                    if method.argumentCount > 0 {
                                        selectedArgumentMethod = method
                                    } else {
                                        withAnimation(.smooth(duration: 0.08)) {
                                            viewModel.invoke(method)
                                        }
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

                if disabledMethods.isEmpty == false {
                    Section("Unavailable Methods") {
                        ForEach(disabledMethods) {
                            methodRow($0).opacity(0.8)
                        }
                    }
                }
            }
            .padding(.bottom) // to prevent the overlay from overlaping with the list rows
            .inlinedNavigationTitle(viewModel.resolvedInstance.inspectorTitle)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search members")
            .overlay(alignment: .bottom) {
                if let lastInvocation = viewModel.lastInvocation {
                    lastResultView(lastInvocation)
                }
            }
            .sheet(item: $selectedArgumentMethod) { method in
                MethodInvocationArgumentsView(method: method) {
                    viewModel.invoke(method, arguments: $0)
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
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        hapticFeedback(.rigid)
                        viewModel.refresh()
                    }
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
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredMethods: [InspectableMethod] {
        viewModel.methods.filter { method in
            canInvoke(method) &&
            methodMatchesSearch(method) &&
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
            methodMatchesSearch(method) &&
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
            propertyMatchesSearch(property) &&
            shouldIncludeMember(
                isInherited: property.isInherited,
                isNSObjectMember: property.isNSObjectMember,
                isAccessibilityRelated: property.isAccessibilityRelated
            )
        }
    }


    private func propertyMatchesSearch(_ property: InspectableProperty) -> Bool {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearchText.isEmpty { return true }
        return [
            property.name,
            property.getterName,
            property.attributes,
            property.valueDescription,
            property.declaringClassName
        ].contains { $0.localizedCaseInsensitiveContains(trimmedSearchText) }
    }

    private func methodMatchesSearch(_ method: InspectableMethod) -> Bool {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearchText.isEmpty { return true }
        return [
            method.selectorName,
            method.returnTypeEncoding,
            method.declaringClassName,
            method.invocationBlockedReason ?? ""
        ].contains { $0.localizedCaseInsensitiveContains(trimmedSearchText) }
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

    private func lastResultView(_ lastInvocation: InvocationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last Result")
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    hapticFeedback(.soft)
                    UIPasteboard.general.string = lastInvocation.valueDescription
                    presentToast(.appToast(icon: "doc.on.doc", message: "Copied result"))
                } label: {
                    Image(systemName: "square.on.square")
                        .foregroundStyle(.lime.gradient)
                        .padding(4)
                        .background(.gray.quinary.opacity(0.6), in: .capsule)
                }
                
                Button {
                    hapticFeedback(.soft)
                    viewModel.clearLastInvocationResult()
                } label: {
                    Text("Close")
                        .font(.system(.caption2, design: .default, weight: .medium))
                        .foregroundStyle(.pink.gradient)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.pink.quinary.opacity(0.6), in: .capsule)
                }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.plain)
            

            Text(lastInvocation.selectorName)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.gray)
                .lineLimit(1)
                .truncationMode(.middle)

            if let errorMessage = lastInvocation.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(lastInvocation.valueDescription)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 140)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(white: 0.25), lineWidth: 1)
                .fill(Color(white: 0.12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .transition(.move(edge: .bottom))
    }

    private func methodRow(_ method: InspectableMethod) -> some View {
        HStack {
            let canInvoke = canInvoke(method)
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
                    .foregroundColor(canInvoke ? .secondary : .orange)
            }

            Spacer(minLength: 12)

            Image(systemName: canInvoke ? "play.fill" : "lock.fill")
                .foregroundStyle(canInvoke ? .blue : .secondary)
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
