// swift-tools-version:6.3
import PackageDescription

let package = Package(
  name: "swift-sh",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "swift-sh", targets: ["Sh"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.1"),
    .package(url: "https://github.com/mxcl/Path.swift", from: "1.6.0"),
    .package(url: "https://github.com/mxcl/StreamReader", from: "1.0.1"),
    .package(url: "https://github.com/mxcl/LegibleError", from: "1.0.6"),
    .package(url: "https://github.com/mxcl/Version", from: "2.2.1"),
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.10.0"),
  ],
  targets: [
    .executableTarget(
      name: "Sh",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "LegibleError",
        "StreamReader",
        "Version",
        .product(name: "Path", package: "Path.swift"),
        "CryptoSwift",
      ]),
    .testTarget(
      name: "ShTests",
      dependencies: [
        "Sh",
        "StreamReader",
        "Version",
        .product(name: "Path", package: "Path.swift"),
      ]),
  ]
)
