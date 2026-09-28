// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WisprKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WisprKit", targets: ["WisprKit"]),
    ],
    targets: [
        .target(name: "WisprKit"),
        .executableTarget(name: "wispr-probe", dependencies: ["WisprKit"]),
        .testTarget(name: "WisprKitTests", dependencies: ["WisprKit"]),
    ]
)
