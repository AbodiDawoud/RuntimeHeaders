//
//  CodeColorTheme.swift
//  HeaderViewer
    

import SwiftUI


struct Theme {
    var name: String
    
    var standard: Color
    var comment: Color
    var keyword: Color
    var variable: Color
    var number: Color
    var recordName: Color
    var `class`: Color
    var `protocol`: Color
    var defaultValue: Color
}


extension Theme {
    static let system = Theme(
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
    
    static let xcodeLight = Theme(
        name: "Xcode Light",
        standard: Color(hex: "#000000"),       // Standard text (black)
        comment: Color(hex: "#A0A0A0"),        // Comments (light gray)
        keyword: Color(hex: "#0000FF"),        // Keywords (bright blue)
        variable: Color(hex: "#000000"),       // Variables (black, same as standard)
        number: Color(hex: "#1C00CF"),         // Numbers (deep blue — your original is good)
        recordName: Color(hex: "#C80000"),     // Structs/enums (rich red)
        class: Color(hex: "#6E2CA0"),          // Class names (purple)
        protocol: Color(hex: "#6E2CA0"),       // Protocols (same as class)
        defaultValue: Color(hex: "#000000")    // Fallback (black)
    )
    
    static let xcodeDark = Theme(
        name: "Xcode Dark",
        standard: Color(hex: "#FFFFFF"),       // Standard text (white)
        comment: Color(red: 0.505882, green: 0.545098, blue: 0.592157),
        keyword: Color(red: 0.937255, green: 0.505882, blue: 0.694118),
        variable: Color(red: 0.411765, green: 0.682353, blue: 0.784314),
        number: Color(red: 0.843137, green: 0.788235, blue: 0.52549),
        recordName: Color(red: 0.933333, green: 0.533333, blue: 0.462745),     // Strings..
        class: Color(red: 0.541176, green: 0.866667, blue: 0.984314),    // Class names
        protocol: Color(red: 0.835294, green: 0.737255, blue: 0.984314), // Protocols Inheritance
        defaultValue: Color(hex: "#FFFFFF")    // Fallback (rare case)
    )
    
    static let githubLight = Theme(
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
    
    static let githubDark = Theme(
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

    static let solarizedLight = Theme(
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
    
    static let solarizedDark = Theme(
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
}
