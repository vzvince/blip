// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Blip",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Blip", targets: ["Blip"]),
        .executable(name: "blip", targets: ["blip-cli"]),
        .executable(name: "BlipApp", targets: ["BlipApp"]),
    ],
    targets: [
        .target(name: "Blip"),
        .executableTarget(name: "blip-cli", dependencies: ["Blip"], path: "Sources/blip-cli"),
        .executableTarget(name: "BlipApp", dependencies: ["Blip"]),
        .testTarget(name: "BlipTests", dependencies: ["Blip"]),
    ]
)
