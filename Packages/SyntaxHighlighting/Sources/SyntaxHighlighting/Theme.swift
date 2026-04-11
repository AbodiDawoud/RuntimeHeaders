//
//  Theme.swift
//  SyntaxHighlighting

import SwiftUI

public struct Theme {
    public var name: String
    
    public var standard: Color
    public var comment: Color
    public var keyword: Color
    public var variable: Color
    public var number: Color
    public var recordName: Color
    public var `class`: Color
    public var `protocol`: Color
    public var defaultValue: Color
    
    public init(
        name: String,
        standard: Color,
        comment: Color,
        keyword: Color,
        variable: Color,
        number: Color,
        recordName: Color,
        `class`: Color,
        `protocol`: Color,
        defaultValue: Color
    ) {
        self.name = name
        self.standard = standard
        self.comment = comment
        self.keyword = keyword
        self.variable = variable
        self.number = number
        self.recordName = recordName
        self.class = `class`
        self.protocol = `protocol`
        self.defaultValue = defaultValue
    }
}


extension Theme {
    @MainActor public static let system = Theme(
        name: "System",
        standard: Color.primary,
        comment: Color.gray,
        keyword: Color.pink,
        variable: Color.primary,
        number: Color.primary,
        recordName: Color.cyan,
        class: Color.mint,
        protocol: Color.teal,
        defaultValue: Color.primary
    )
    
    @MainActor public static let xcodeLight = Theme(
        name: "Xcode Light",
        // Mapped from Xcode 16.4 Default (Light).xccolortheme.
        standard: Color(hex: "#262626"),       // xcode.syntax.plain composited over source background
        comment: Color(hex: "#5D6C79"),        // xcode.syntax.comment
        keyword: Color(hex: "#9B2393"),        // xcode.syntax.keyword
        variable: Color(hex: "#326D74"),       // xcode.syntax.identifier.variable
        number: Color(hex: "#1C00CF"),         // xcode.syntax.number
        recordName: Color(hex: "#C41A16"),     // xcode.syntax.string
        class: Color(hex: "#1C464A"),          // xcode.syntax.identifier.class
        protocol: Color(hex: "#3900A0"),       // xcode.syntax.identifier.type.system
        defaultValue: Color(hex: "#262626")
    )
    
    @MainActor public static let xcodeDark = Theme(
        name: "Xcode Dark",
        // Mapped from Xcode 16.4 Default (Dark).xccolortheme.
        standard: Color(hex: "#DDDDDE"),       // xcode.syntax.plain composited over source background
        comment: Color(hex: "#6C7986"),        // xcode.syntax.comment
        keyword: Color(hex: "#FC5FA3"),        // xcode.syntax.keyword
        variable: Color(hex: "#67B7A4"),       // xcode.syntax.identifier.variable
        number: Color(hex: "#D0BF69"),         // xcode.syntax.number
        recordName: Color(hex: "#FC6A5D"),     // xcode.syntax.string
        class: Color(hex: "#9EF1DD"),          // xcode.syntax.identifier.class
        protocol: Color(hex: "#D0A8FF"),       // xcode.syntax.identifier.type.system
        defaultValue: Color(hex: "#DDDDDE")
    )
    
    @MainActor public static let githubLight = Theme(
        name: "Github Light",
        standard: Color(hex: "#24292e"),     // GitHub text color
        comment: Color(hex: "#6a737d"),      // muted comment gray
        keyword: Color(hex: "#d73a49"),      // red/pink
        variable: Color(hex: "#005cc5"),     // blue
        number: Color(hex: "#005cc5"),       // same blue
        recordName: Color(hex: "#6f42c1"),   // purple
        class: Color(hex: "#e36209"),        // orange
        protocol: Color(hex: "#22863a"),   // green
        defaultValue: Color(hex: "#24292e")  // fallback text
    )
    
    @MainActor public static let githubDark = Theme(
        name: "GithubDark",
        standard: Color(hex: "#c9d1d9"),     // default text (grayish white)
        comment: Color(hex: "#8b949e"),      // light gray for muted comments
        keyword: Color(hex: "#ff7b72"),      // soft red/pink (vs d73a49 in light)
        variable: Color(hex: "#79c0ff"),     // lighter blue (vs 005cc5)
        number: Color(hex: "#b392f0"),       // soft purple for numbers
        recordName: Color(hex: "#d2a8ff"),   // light purple (vs 6f42c1)
        class: Color(hex: "#ffa657"),        // lighter orange (vs e36209)
        protocol: Color(hex: "#7ee787"),   // soft green (vs 22863a)
        defaultValue: Color(hex: "#c9d1d9")  // same as standard
    )

    @MainActor public static let solarizedLight = Theme(
        name: "Solarized Light",
        standard: Color(hex: "#586e75"),
        comment: Color(hex: "#93a1a1"),
        keyword: Color(hex: "#859900"),
        variable: Color(hex: "#268bd2"),
        number: Color(hex: "#2aa198"),
        recordName: Color(hex: "#6c71c4"),
        class: Color(hex: "#d33682"),
        protocol: Color(hex: "#cb4b16"),
        defaultValue: Color(hex: "#586e75")
    )
    
    @MainActor public static let solarizedDark = Theme(
        name: "Solarized Dark",
        standard: Color(hex: "#93a1a1"),
        comment: Color(hex: "#586e75"),
        keyword: Color(hex: "#b58900"),
        variable: Color(hex: "#268bd2"),
        number: Color(hex: "#2aa198"),
        recordName: Color(hex: "#6c71c4"),
        class: Color(hex: "#d33682"),
        protocol: Color(hex: "#cb4b16"),
        defaultValue: Color(hex: "#93a1a1")
    )

    @MainActor public static let classicLight = Theme(
        name: "Classic Light",
        standard: Color(hex: "#262626"),
        comment: Color(hex: "#267507"),
        keyword: Color(hex: "#9B2393"),
        variable: Color(hex: "#326D74"),
        number: Color(hex: "#1C00CF"),
        recordName: Color(hex: "#C41A16"),
        class: Color(hex: "#1C464A"),
        protocol: Color(hex: "#3900A0"),
        defaultValue: Color(hex: "#262626")
    )

    @MainActor public static let classicDark = Theme(
        name: "Classic Dark",
        standard: Color(hex: "#DDDDDE"),
        comment: Color(hex: "#73A74E"),
        keyword: Color(hex: "#FC5FA3"),
        variable: Color(hex: "#67B7A4"),
        number: Color(hex: "#D0BF69"),
        recordName: Color(hex: "#FC6A5D"),
        class: Color(hex: "#9EF1DD"),
        protocol: Color(hex: "#D0A8FF"),
        defaultValue: Color(hex: "#DDDDDE")
    )

    @MainActor public static let civic = Theme(
        name: "Civic",
        standard: Color(hex: "#E1E2E7"),
        comment: Color(hex: "#45BB3E"),
        keyword: Color(hex: "#D7008F"),
        variable: Color(hex: "#1DA9A2"),
        number: Color(hex: "#149C92"),
        recordName: Color(hex: "#D3232E"),
        class: Color(hex: "#1DA9A2"),
        protocol: Color(hex: "#25908D"),
        defaultValue: Color(hex: "#E1E2E7")
    )

    @MainActor public static let dusk = Theme(
        name: "Dusk",
        standard: Color(hex: "#FFFFFF"),
        comment: Color(hex: "#41B645"),
        keyword: Color(hex: "#B21889"),
        variable: Color(hex: "#83C057"),
        number: Color(hex: "#786DC4"),
        recordName: Color(hex: "#DB2C38"),
        class: Color(hex: "#83C057"),
        protocol: Color(hex: "#00A0BE"),
        defaultValue: Color(hex: "#FFFFFF")
    )

    @MainActor public static let midnight = Theme(
        name: "Midnight",
        standard: Color(hex: "#FFFFFF"),
        comment: Color(hex: "#41CC45"),
        keyword: Color(hex: "#D31895"),
        variable: Color(hex: "#23FF83"),
        number: Color(hex: "#786DFF"),
        recordName: Color(hex: "#FF2C38"),
        class: Color(hex: "#23FF83"),
        protocol: Color(hex: "#00A0FF"),
        defaultValue: Color(hex: "#FFFFFF")
    )

    @MainActor public static let sunset = Theme(
        name: "Sunset",
        standard: Color(hex: "#000000"),
        comment: Color(hex: "#C3741C"),
        keyword: Color(hex: "#294277"),
        variable: Color(hex: "#476A97"),
        number: Color(hex: "#294277"),
        recordName: Color(hex: "#DF0700"),
        class: Color(hex: "#B44500"),
        protocol: Color(hex: "#B44500"),
        defaultValue: Color(hex: "#000000")
    )

    @MainActor public static let lowKey = Theme(
        name: "Low Key",
        standard: Color(hex: "#000000"),
        comment: Color(hex: "#435138"),
        keyword: Color(hex: "#262C6A"),
        variable: Color(hex: "#476A97"),
        number: Color(hex: "#262C6A"),
        recordName: Color(hex: "#702C51"),
        class: Color(hex: "#476A97"),
        protocol: Color(hex: "#476A97"),
        defaultValue: Color(hex: "#000000")
    )
}


public extension Color {
    func toHex() -> String {
        let components = UIColor(self).cgColor.components!
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
