// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SpeechRecognitionClient",
    platforms: [
        .iOS(.v17), .macOS(.v14),
    ],
    products: [
        .singleTargetLibrary("SpeechRecognitionClient"),
        .singleTargetLibrary("SpeechRecognitionClientLive"),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "SpeechRecognitionClient",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "SpeechRecognitionClientLive",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "SpeechRecognitionClient",
            ]
        ),
    ]
)

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}
