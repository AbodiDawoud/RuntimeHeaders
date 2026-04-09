//
//  IconicLabelStyle.swift
//  HeaderViewer
    

import SwiftUI


struct IconicLabelStyle: LabelStyle {
    private let color: Color
    
    init(_ color: Color) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .symbolRenderingMode(.hierarchical)
                .background(color.gradient, in: .rect(cornerRadius: 10.5))
                .padding(.vertical, 1.2)
            
            configuration.title
        }
    }
}

struct EmptyStatusLabelStyle: LabelStyle {
    private let foreground: Color
    private let secondary: Color
    private let extraInfo: String
    
    init(_ foreground: Color, secondary: Color = .primary, info: String) {
        self.foreground = foreground
        self.secondary = secondary
        self.extraInfo = info
    }
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 14) {
            configuration.icon
                .foregroundStyle(secondary, foreground.gradient)
                .font(.largeTitle)
                .symbolRenderingMode(.palette)
                .shadow(color: foreground, radius: 45)
            
            VStack(spacing: 5) {
                configuration.title
                    .font(.title2.weight(.bold))
                
                Text(extraInfo)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}
