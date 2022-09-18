// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Persistence",
            targets: ["Persistence"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SparrowTek/realm-swift", from: "10.28.0"),
    ],
    targets: [
        .target(
            name: "Persistence",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-swift"),
            ])
    ]
)
