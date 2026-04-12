//
//  FeaturedFrameworkContainerView.swift
//  RuntimeHeaders
    

import SwiftUI

struct FFContainerView: View {
    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(featuredFrameworkNodes) { item in
                        NavigationLink(value: item.node) {
                            FFCardView(framework: item.framework)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.init())
            .listRowSeparator(.hidden)
        } header: {
            Text("Recommended Frameworks")
        } footer: {
            Text("Get started by exploring these system frameworks..")
        }
    }
    
    private var featuredFrameworkNodes: [FeaturedFrameworkNode] {
        FeaturedFramework.frameworks.compactMap { framework in
            guard let node = framework.node() else { return nil }
            return FeaturedFrameworkNode(framework: framework, node: node)
        }
    }
}


struct FFCardView: View {
    let framework: FeaturedFramework
    private let theme: [Color] = [.indigo, .blue, .cyan]
    
    
    var body: some View {
        Image(framework.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 90)
            .frame(width: 300, height: 150)
            .padding(.bottom, 30)
            .background(Color(white: 0.1), in: .rect(cornerRadius: 12))
            .compositingGroup()
            .overlay(alignment: .bottom) {
                HStack {
                    Text(framework.title)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                }
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    Capsule()
                        .stroke(Color(white: 0.25), lineWidth: 1)
                        .fill(Color(white: 0.15))
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 7)
            }
    }
}
