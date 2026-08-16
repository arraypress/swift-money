// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-money",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "Money", targets: ["Money"]),
    ],
    targets: [
        .target(name: "Money"),
        .testTarget(name: "MoneyTests", dependencies: ["Money"]),
    ]
)
