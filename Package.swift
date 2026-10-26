// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MojoCalendarBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MojoCalendarBar", path: "Sources/MojoCalendarBar")
    ]
)
