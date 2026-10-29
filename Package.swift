// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "PodsMic",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PodsMic",
            path: "Sources/PodsMic"
        )
    ]
)
