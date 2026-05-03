// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HabibiFloat",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HabibiFloat", targets: ["HabibiFloat"])
    ],
    targets: [
        .target(name: "HabibiFloatCore"),
        .executableTarget(
            name: "HabibiFloat",
            dependencies: ["HabibiFloatCore"],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "HabibiFloatCoreTests",
            dependencies: ["HabibiFloatCore"]
        )
    ]
)
