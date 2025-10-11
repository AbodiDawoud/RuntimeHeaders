//
//  AppearancePopover.swift
//  HeaderViewer
    

import SwiftUI

struct AppearancePopoverView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    
    var appAppearance: String {
        settingsManager.preferences.preferredColorScheme
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 55) {
                colorSchemeButton("light")
                
                colorSchemeButton("dark")
            }.padding(.horizontal, 60)
            
            Divider()
                .padding(.horizontal, -60)
                .padding(.vertical, 4)
            
            Toggle("System", isOn: systemSchemeBinding)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(.thickMaterial)
        .presentationCompactAdaptation(.popover)
    }
    
    var systemSchemeBinding: Binding<Bool> {
        .init {
            return appAppearance == "nil"
        } set: {
            settingsManager.preferences.preferredColorScheme = $0 ? "nil" : "dark"
        }
    }
    
    private func colorSchemeButton(_ scheme: String) -> some View {
        Button {
            settingsManager.preferences.preferredColorScheme = scheme
        } label: {
            VStack(spacing: 15) {
                ZStack {
                    Image("Appearance-\(scheme)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60)
                        .padding(.top, 5)
                    
                    Text("9:41")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.bottom, 70)
                }
                
                Text(scheme.capitalized)
                    .font(.subheadline)
                    .padding(.bottom, -5)
                
                Image(systemName: appAppearance == scheme ? "checkmark.circle.fill": "circle")
                    .foregroundStyle(appAppearance == scheme ? Color.white : Color.secondary, .blue)
                    .fontWeight(.light)
                    .imageScale(.large)
            }
        }
        .buttonStyle(.plain)
    }
}
