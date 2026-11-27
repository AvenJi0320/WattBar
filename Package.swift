// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WattBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "WattBar", targets: ["WattBar"]),
        .executable(name: "wattbar-probe", targets: ["WattBarProbe"]),
    ],
    targets: [
        .target(name: "CSMC", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "WattBarCore"),
        .target(
            name: "WattBarSystem",
            dependencies: ["WattBarCore", "CSMC"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(name: "WattBar", dependencies: ["WattBarCore", "WattBarSystem"]),
        .executableTarget(name: "WattBarProbe", dependencies: ["WattBarCore", "WattBarSystem"]),
        .testTarget(
            name: "WattBarCoreTests",
            dependencies: ["WattBarCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
