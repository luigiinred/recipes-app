// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Recipes",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "RecipeKit", targets: ["RecipeKit"]),
        .executable(name: "recipes", targets: ["recipes"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "RecipeKit"),
        .executableTarget(
            name: "recipes",
            dependencies: [
                "RecipeKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "RecipeKitTests", dependencies: ["RecipeKit"]),
    ]
)
