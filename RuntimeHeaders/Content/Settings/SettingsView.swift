//
//  SettingsView.swift
//  HeaderViewer
    

import SwiftUI


struct SettingsView: View {
    @ObservedObject private var manager: PreferenceController = .shared
    @EnvironmentObject private var historyManager: HistoryManager
    
    @State private var showAppearancePopover: Bool = false
    @State private var showCodeAppearanceCover: Bool = false
    
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("App Appearance", image: .appearanceLuminosity) {
                        showAppearancePopover.toggle()
                    }
                    .popover(isPresented: $showAppearancePopover, content: AppearancePopoverView.init)
                    .labelStyle(IconicLabelStyle(Color(red: 0.937255, green: 0.596078, blue: 0.419608)))
                    
                    Button {
                        showCodeAppearanceCover = true
                    } label: {
                        Label("Code Appearance", systemImage: "ellipsis.curlybraces")
                            .labelStyle(IconicLabelStyle(.orchid))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 1.5)

                
                Section("History") {
                    Toggle(
                        "Track History",
                        image: .clockArrowTriangleheadClockwiseRotate90PathDotted,
                        isOn: $manager.preferences.historyEnabled.animation()
                    )
                    .labelStyle(IconicLabelStyle(Color(red: 0.92549, green: 0.411765, blue: 0.505882)))
                    .tint(Color(red: 0.352941, green: 0.619608, blue: 0.729412))
                    
                    if manager.preferences.historyEnabled {
                        Toggle(
                            "Badge Enabled",
                            systemImage: "app.badge.clock.fill",
                            isOn: $manager.preferences.historyBadgeEnabled.animation()
                        )
                        .labelStyle(IconicLabelStyle(Color(red: 0.352941, green: 0.619608, blue: 0.729412)))
                        .tint(Color(red: 0.352941, green: 0.619608, blue: 0.729412))
                        
                        Stepper(value: $manager.preferences.historyLimit.animation(), in: 0...100, step: 10) {
                            let limit = manager.preferences.historyLimit == 0 ? "Unlimited" : String(manager.preferences.historyLimit)
                            
                            HStack(spacing: 0) {
                                Label("Limit: ", systemImage: "number")
                                    .labelStyle(IconicLabelStyle(Color(red: 0.486275, green: 0.427451, blue: 0.917647)))
                                
                                Text(limit)
                                    .foregroundStyle(.gray)
                                    .font(.callout)
                                    .contentTransition(.numericText())
                            }
                        }
                    }
                }
                .padding(.vertical, 1.5)
                
                
                RestoreFrameworkSection()
                CacheSection()
            }
            .buttonStyle(.plain)
            .inlinedNavigationTitle("Settings")
            .fullScreenCover(isPresented: $showCodeAppearanceCover, content: CodeAppearanceView.init)
        }
    }
}

fileprivate struct RestoreFrameworkSection: View {
    @ObservedObject private var manager: PreferenceController = .shared
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        Section {
            Toggle(
                "Open Last Framework on Launch",
                systemImage: "arrow.trianglehead.clockwise.rotate.90",
                isOn: $manager.preferences.restoreLastFrameworkOnLaunch.animation()
            )
            .labelStyle(IconicLabelStyle(.blue))
            .tint(.blue)
            
            if let lastFrameworkPath = LastNodeTracker.path {
                VStack(alignment: .leading) {
                    HStack {
                        Text("current")
                            .foregroundStyle(.secondary)
                            .textScale(.secondary)
                            .font(.subheadline.weight(.medium))
                            .textCase(.uppercase)
                        Spacer()
                        Button(action: LastNodeTracker.reset) {
                            Text("Clear")
                                .font(.system(.caption2, design: .default, weight: .medium))
                                .foregroundStyle(.pink.gradient)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    .pink.quinary.opacity(scheme == .light ? 0.4 : 0.95), in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(lastFrameworkPath)
                        .font(.subheadline)
                }
            }
        } footer: {
            Text("When enabled, the app navigates directly to the last framework or image list you viewed.")
        }
        .padding(.vertical, 1.5)
    }
}



fileprivate struct CacheSection: View {
    @ObservedObject private var manager: PreferenceController = .shared
    @State private var showCacheClearConfirmation: Bool = false
    
    var body: some View {
        Section {
            Button {
                showCacheClearConfirmation.toggle()
            } label: {
                LabeledContent {
                    Text(manager.cacheSize)
                } label: {
                    Label("Cache Size", systemImage: "bolt.fill")
                        .labelStyle(IconicLabelStyle(Color(red: 0.384314, green: 0.717647, blue: 0.490196)))
                }
            }
        }
        .padding(.vertical, 1)
        .onAppear(perform: manager.calculateCacheSize)
        .confirmationDialog("", isPresented: $showCacheClearConfirmation) {
            Button("Clear", role: .destructive, action: manager.clearCache)
        }
    }
}
