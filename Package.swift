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
            path: "Hermes_IOS/HermesCore"
        ),
        .target(
            name: "HermesCapabilities",
            dependencies: ["HermesCore"],
            path: "Hermes_IOS/HermesCapabilities"
        ),
        .target(
            name: "HermesWebView",
            dependencies: ["HermesCore", "HermesCapabilities"],
            path: "Hermes_IOS/HermesWebView"
        ),
        .target(
            name: "HermesUI",
            dependencies: ["HermesCore", "HermesCapabilities"],
            path: "Hermes_IOS/HermesUI"
        ),
        .target(
            name: "HermesApp",
            dependencies: ["HermesCore", "HermesCapabilities", "HermesWebView", "HermesUI"],
            path: "Hermes_IOS",
            exclude: ["Info.plist", "Assets.xcassets", "HermesApp"]
        ),
        .testTarget(
            name: "HermesiOSTests",
            dependencies: ["HermesCore", "HermesCapabilities"],
            path: "Tests/HermesiOSTests"
        ),
    ]
)
