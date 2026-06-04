// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PromptPocket",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PromptPocket", targets: ["PromptPocket"]),
        .library(name: "PromptPocketCore", targets: ["PromptPocketCore"]),
        .executable(name: "PromptPocketCoreBehaviorTests", targets: ["PromptPocketCoreBehaviorTests"])
    ],
    targets: [
        .target(name: "PromptPocketCore"),
        .executableTarget(name: "PromptPocket", dependencies: ["PromptPocketCore"]),
        .executableTarget(name: "PromptPocketCoreBehaviorTests", dependencies: ["PromptPocketCore"], path: "Tests/PromptPocketCoreBehaviorTests")
    ]
)
