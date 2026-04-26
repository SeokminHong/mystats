// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "mystats",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mystats", targets: ["MystatsApp"])
    ],
    targets: [
        .target(
            name: "MystatsCore",
            path: "Sources/MystatsCore"
        ),
        .executableTarget(
            name: "MystatsApp",
            dependencies: ["MystatsCore"],
            path: "Sources/MystatsApp"
        ),
        .testTarget(
            name: "MystatsCoreTests",
            dependencies: ["MystatsCore"],
            path: "Tests/MystatsCoreTests"
        )
    ]
)

