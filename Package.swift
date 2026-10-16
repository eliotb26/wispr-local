// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "wispr-local",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "WisprLocalCore"),
        .executableTarget(name: "wispr-local", dependencies: ["WisprLocalCore"]),
        .testTarget(name: "WisprLocalCoreTests", dependencies: ["WisprLocalCore"]),
    ]
)
