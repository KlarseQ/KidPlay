// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KidPlay",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KidPlay",
            path: "Sources/KidPlay",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SpriteKit"),
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
    ]
)
