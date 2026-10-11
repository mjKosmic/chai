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
            name: "Latte",
            targets: ["Latte"]
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
            name: "Latte",
            dependencies: ["Chai"],
            path: "Sources/Latte"
        ),
        .target(
            name: "Spices",
            dependencies: ["Chai", "Latte"],
            path: "Sources/Spices"
        ),
        .testTarget(
            name: "ChaiTests",
            // LayoutEngineTests (M1) exercises the engine with Latte's
            // VStack/HStack containers, so the target depends on Latte.
            dependencies: ["Chai", "Latte"],
            path: "Tests/ChaiTests"
        ),
        .testTarget(
            name: "LatteTests",
            dependencies: ["Latte"],
            path: "Tests/LatteTests"
        ),
        .testTarget(
            name: "SpicesTests",
            dependencies: ["Spices"],
            path: "Tests/SpicesTests"
        ),
        .executableTarget(
            name: "GroceryList",
            dependencies: ["Chai", "Spices", "Latte"],
            path: "Examples/GroceryList/Sources"
        ),
    ]
)
