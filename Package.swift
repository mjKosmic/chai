// swift-tools-version: 6.1
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
        .library(
            name: "Spices",
            targets: ["Spices"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Chai",
            path: "Sources/Chai"
        ),
        .target(
            name: "Spices",
            dependencies: ["Chai"],
            path: "Sources/Spices"
        ),
        .testTarget(
            name: "ChaiTests",
            dependencies: ["Chai"],
            path: "Tests/ChaiTests"
        ),
        .testTarget(
            name: "ChaiViewTests",
            dependencies: ["Chai"],
            path: "Tests/ChaiViewTests"
        ),
        .testTarget(
            name: "SpicesTests",
            dependencies: ["Spices"],
            path: "Tests/SpicesTests"
        ),
        .executableTarget(
            name: "GroceryList",
            dependencies: ["Chai", "Spices"],
            path: "Examples/GroceryList/Sources"
        ),
    ]
)
