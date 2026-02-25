// swift-tools-version: 6.1.2
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
