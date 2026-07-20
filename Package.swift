// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Notch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Notch", targets: ["Notch"])
    ],
    targets: [
        .executableTarget(
            name: "Notch",
            path: "Sources/Notch",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NotchTests",
            dependencies: ["Notch"],
            path: "Tests/NotchTests"
        )
    ]
)
