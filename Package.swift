// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrappleTimer",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GrappleTimer",
            targets: ["GrappleTimer"]),
    ],
    targets: [
        .target(
            name: "GrappleTimer",
            dependencies: [],
            path: "GrappleTimer",
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "GrappleTimerTests",
            dependencies: ["GrappleTimer"],
            path: "GrappleTimerTests"),
    ]
)
