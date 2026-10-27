// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WhisperKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WhisperKit", targets: ["WhisperKit"]),
    ],
    targets: [
        .target(name: "WhisperKit"),
        .executableTarget(name: "whisper-probe", dependencies: ["WhisperKit"]),
        .testTarget(name: "WhisperKitTests", dependencies: ["WhisperKit"]),
    ]
)
