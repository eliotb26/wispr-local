// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "flowfree",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "flowfree", path: "Sources/flowfree")
    ]
)
