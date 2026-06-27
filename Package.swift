// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchPaw",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchPaw", targets: ["NotchPaw"]),
        .library(name: "NotchPawCore", targets: ["NotchPawCore"]),
    ],
    targets: [
        .target(name: "NotchPawCore"),
        .executableTarget(
            name: "NotchPaw",
            dependencies: ["NotchPawCore"]
        ),
        // Plain executable test harness (Command Line Tools have no XCTest).
        .executableTarget(
            name: "notchpaw-selftest",
            dependencies: ["NotchPawCore"]
        ),
    ]
)
