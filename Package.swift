// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RetryKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "RetryKit", targets: ["RetryKit"])
    ],
    targets: [
        .target(
            name: "RetryKit"
        ),
        .testTarget(
            name: "RetryKitTests",
            dependencies: ["RetryKit"]
        )
    ]
)
