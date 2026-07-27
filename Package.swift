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
    dependencies: [
        .package(url: "https://github.com/Ebullioscopic/AtollExtensionKit.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "Blip", dependencies: [
            .product(name: "AtollExtensionKit", package: "AtollExtensionKit"),
        ]),
        .executableTarget(name: "blip-cli", dependencies: ["Blip"], path: "Sources/blip-cli"),
        .executableTarget(name: "BlipApp", dependencies: [
            "Blip",
            .product(name: "AtollExtensionKit", package: "AtollExtensionKit"),
        ]),
        .testTarget(name: "BlipTests", dependencies: ["Blip"]),
    ]
)
