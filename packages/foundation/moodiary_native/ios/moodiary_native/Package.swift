// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "moodiary_native",
    platforms: [
        .iOS("16.4")
    ],
    products: [
        .library(name: "moodiary-native", targets: ["moodiary_native"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "moodiary_native",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
