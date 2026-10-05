// swift-tools-version:6.3
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu
import PackageDescription

let package = Package(
  name: "swift-sh",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "swift-sh", targets: ["SwiftSh"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", "1.8.1"..<"1.9.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "603.0.0"..<"604.0.0"),
    .package(url: "https://github.com/apple/swift-system", "1.8.1"..<"1.9.0"),
    .package(url: "https://github.com/swiftlang/swift-subprocess", "1.0.0"..<"1.1.0"),
    .package(url: "https://github.com/apple/swift-crypto", "5.0.0"..<"5.1.0"),
    .package(url: "https://github.com/swift-library/swift-semver", .upToNextMinor(from: "0.1.0")),
  ],
  targets: [
    .executableTarget(
      name: "SwiftSh",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SystemPackage", package: "swift-system"),
        .product(name: "Subprocess", package: "swift-subprocess"),
        .product(name: "SemVer", package: "swift-semver"),
        .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
      ]),
    .testTarget(
      name: "SwiftShTests",
      dependencies: [
        "SwiftSh",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SemVer", package: "swift-semver"),
        .product(name: "SystemPackage", package: "swift-system"),
        .product(name: "Subprocess", package: "swift-subprocess"),
      ]),
  ]
)
