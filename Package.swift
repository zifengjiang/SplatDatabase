// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Splat3Database",
    products: [
        .library(
            name: "Splat3Database",
            targets: ["Splat3Database"]),
    ],
    dependencies: [
        // Declare the dependency on GRDB
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.27.0"),
        /// swiftyjson
          .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.2")
    ],
    targets: [
        .target(
            name: "Splat3Database",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON")
            ]
        ),
        .testTarget(
            name: "Splat3DatabaseTests",
            dependencies: ["Splat3Database"]),
        .testTarget(name: "DatabaseManagerTests",dependencies: ["Splat3Database", .product(name: "GRDB", package: "GRDB.swift")])
    ]
)
