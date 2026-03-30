// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "VoiceIME",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceIME", targets: ["VoiceIME"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceIME",
            path: "Sources/VoiceIME"
        )
    ]
)
