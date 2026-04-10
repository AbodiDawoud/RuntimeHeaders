// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RuntimeInspectorKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "RuntimeInspectorKit",
            targets: ["RuntimeInspectorKit"]
        )
    ],
    targets: [
        .target(
            name: "RuntimeInspectorKit"
        )
    ]
)
