// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AIShellGuard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AIShellGuard",
            targets: ["AIShellGuard"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIShellGuard",
            dependencies: [],
            path: "SSHGuard",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AIShellGuardTests",
            dependencies: ["AIShellGuard"],
            path: "SSHGuardTests"
        )
    ]
)
