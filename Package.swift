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
        .library(name: "HermesBridge", targets: ["HermesBridge"]),
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
            name: "HermesBridge",
            dependencies: ["HermesCore"],
            path: "Sources/HermesBridge"
        ),
        .target(
            name: "HermesCapabilities",
            dependencies: ["HermesCore"],
            path: "Sources/HermesCapabilities"
        ),
        .target(
            name: "HermesWebView",
            dependencies: ["HermesCore", "HermesBridge", "HermesCapabilities"],
            path: "Sources/HermesWebView"
        ),
        .target(
            name: "HermesUI",
            dependencies: ["HermesCore", "HermesBridge"],
            path: "Sources/HermesUI"
        ),
        .target(
            name: "HermesApp",
            dependencies: ["HermesCore", "HermesBridge", "HermesCapabilities", "HermesWebView", "HermesUI"],
            path: "Sources/HermesApp",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "HermesiOSTests",
            dependencies: ["HermesBridge", "HermesCapabilities", "HermesCore"],
            path: "Tests/HermesiOSTests"
        ),
    ]
)
