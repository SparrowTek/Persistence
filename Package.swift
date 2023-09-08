// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_14),
        .watchOS(.v5),
    ],
    products: [
        .library(
            name: "Persistence",
            targets: ["Persistence"]),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/realm-swift.git", .upToNextMajor(from: "10.0.0")),
    ],
    targets: [
        .target(
            name: "Persistence",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-swift"),
            ]),
    ]
)
