// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ClimateEngine",
    products: [
        .library(
            name: "ClimateEngine",
            targets: ["ClimateEngine"]
        )
    ],
    targets: [
        .target(
            name: "ClimateEngine"
        ),
        .testTarget(
            name: "ClimateEngineTests",
            dependencies: ["ClimateEngine"]
        )
    ],
    swiftLanguageModes: [.v6]
)
