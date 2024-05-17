// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SplatDatabase",
    platforms: [
      .iOS(.v15),
    ],
    products: [
        .library(
            name: "SplatDatabase",
            targets: ["SplatDatabase"]),
    ],
    dependencies: [
        // Declare the dependency on GRDB
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.27.0"),
        /// swiftyjson
          .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.2")
    ],
    targets: [
        .target(
            name: "SplatDatabase",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON")
            ],
            path: "Sources",
            resources: [
              .process("SplatDatabase/Resources")
            ]
        ),
        .testTarget(
            name: "Splat3DatabaseTests",
            dependencies: ["SplatDatabase", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests",
            resources: [
              .process("SplatDatabaseTests/Resources")
            ]
        )
    ]
)
