// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SourceBaseiOS",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SourceBaseiOS", targets: ["SourceBaseiOS"])
    ],
    dependencies: [
        .package(path: "../SourceBaseBackend"),
        .package(url: "https://github.com/markiv/SwiftUI-Shimmer", from: "1.5.1"),
        .package(url: "https://github.com/EmergeTools/Pow", from: "1.0.6"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.6.0")
    ],
    targets: [
        .target(
            name: "SourceBaseiOS",
            dependencies: [
                .product(name: "SourceBaseBackend", package: "SourceBaseBackend"),
                .product(name: "Shimmer", package: "SwiftUI-Shimmer"),
                .product(name: "Pow", package: "Pow"),
                .product(name: "Lottie", package: "lottie-spm")
            ],
            path: "Sources/SourceBaseiOS"
        ),
        .testTarget(
            name: "SourceBaseiOSTests",
            dependencies: ["SourceBaseiOS"],
            path: "Tests/SourceBaseiOSTests"
        )
    ]
)
