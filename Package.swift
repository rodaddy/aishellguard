// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SSHGuard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SSHGuard",
            targets: ["SSHGuard"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SSHGuard",
            dependencies: [],
            path: "SSHGuard"
        ),
        .testTarget(
            name: "SSHGuardTests",
            dependencies: ["SSHGuard"],
            path: "SSHGuardTests"
        )
    ]
)
