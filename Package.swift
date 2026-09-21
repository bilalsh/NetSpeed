// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NetSpeed",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "NetSpeed",
            targets: ["NetSpeed"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NetSpeed"
        )
    ]
)