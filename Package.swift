// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Chai",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Chai",
            targets: ["Chai"]
        ),
    ],
    targets: [
        .target(
            name: "Chai",
            path: "Sources/Chai",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ChaiTests",
            dependencies: ["Chai"],
            path: "Tests/ChaiTests"
        ),
        .executableTarget(
            name: "GroceryList",
            dependencies: ["Chai"],
            path: "Examples/GroceryList/Sources"
        ),
    ]
)
