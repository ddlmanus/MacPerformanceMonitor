// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPerformanceMonitor",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacPerformanceMonitor",
            path: "Sources"
        )
    ]
)
