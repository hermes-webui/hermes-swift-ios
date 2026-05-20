// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HermesiOSLib",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "HermesApp", targets: ["HermesApp"]),
        .library(name: "HermesWebView", targets: ["HermesWebView"]),
        .library(name: "HermesCapabilities", targets: ["HermesCapabilities"]),
        .library(name: "HermesCore", targets: ["HermesCore"]),
        .library(name: "HermesUI", targets: ["HermesUI"]),
    ],
    targets: [
        .target(
            name: "HermesCore",
            path: "Sources/HermesCore"
        ),
        .target(
            name: "HermesCapabilities",
            dependencies: ["HermesCore"],
            path: "Sources/HermesCapabilities"
        ),
        .target(
            name: "HermesWebView",
            dependencies: ["HermesCore", "HermesCapabilities"],
            path: "Sources/HermesWebView"
        ),
        .target(
            name: "HermesUI",
            dependencies: ["HermesCore", "HermesCapabilities"],
            path: "Sources/HermesUI"
        ),
        .target(
            name: "HermesApp",
            dependencies: ["HermesCore", "HermesCapabilities", "HermesWebView", "HermesUI"],
            path: "Sources/HermesApp",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "HermesiOSTests",
            dependencies: ["HermesCore", "HermesCapabilities"],
            path: "Tests/HermesiOSTests"
        ),
    ]
)
