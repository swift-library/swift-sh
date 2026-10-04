// SPDX-License-Identifier: Unlicense

import Foundation
import SystemPackage

struct Script {
  let analysis: ScriptAnalysis
  let cache: BuildCache

  var directory: FilePath { cache.directory(for: analysis.source) }
  var entryName: String { analysis.hasMainAttribute ? "Root.swift" : "main.swift" }
  var entry: FilePath { directory.appending(entryName) }
  var binary: FilePath { directory.appending(".build/debug").appending(analysis.source.name) }

  var manifest: String {
    let name = swiftLiteral(analysis.source.name)
    let target = swiftLiteral("SwiftShScript_" + cache.key(for: analysis.source).prefix(16))
    var seen: Set<String> = []
    let dependencies = analysis.dependencies.map(\.packageLine).filter { seen.insert($0).inserted }
      .joined(separator: ",\n    ")
    let products = analysis.dependencies.map(\.productLine).joined(separator: ", ")
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return """
      // swift-tools-version:6.3
      import PackageDescription

      let package = Package(
        name: \(name),
        products: [.executable(name: \(name), targets: [\(target)])],
        dependencies: [
          \(dependencies)
        ],
        targets: [.executableTarget(
          name: \(target),
          dependencies: [\(products)],
          path: ".",
          sources: [\(swiftLiteral(entryName))]
        )],
        swiftLanguageModes: [.v6]
      )
      #if os(macOS)
      package.platforms = [.macOS("\(version.majorVersion).\(version.minorVersion)")]
      #endif

      """
  }

  /// Generated files are owned copies; changes never write through a link to user source.
  func write() throws {
    let buildPaths =
      [directory.string, analysis.source.name]
      + analysis.dependencies.compactMap { dependency -> String? in
        guard case .local(let path) = dependency.dependencyName else { return nil }
        return path.string
      }
    if let path = buildPaths.first(where: {
      $0.unicodeScalars.contains { $0.value < 32 || $0.value == 34 || $0.value == 92 }
    }) {
      throw SourceError.unsupportedSwiftPMPath(path)
    }
    let manager = FileManager.default
    try manager.createDirectory(at: fileURL(directory), withIntermediateDirectories: true)
    let obsolete = directory.appending(analysis.hasMainAttribute ? "main.swift" : "Root.swift")
    if (try? manager.attributesOfItem(atPath: obsolete.string)) != nil {
      try manager.removeItem(at: fileURL(obsolete))
    }
    if (try? manager.attributesOfItem(atPath: entry.string)[.type] as? FileAttributeType)
      == .typeSymbolicLink
    {
      try manager.removeItem(at: fileURL(entry))
    }
    try writeIfChanged(analysis.source.compilableText, to: entry)
    try writeIfChanged(manifest, to: directory.appending("Package.swift"))
  }

  func build(using toolchain: SwiftToolchain) async throws {
    try write()
    let receipt = directory.appending(".build-record.json")
    let arguments = ["build"]
    let expected = BuildRecord(
      arguments: arguments,
      source: digest(analysis.source.compilableText), manifest: digest(manifest),
      toolchain: toolchain.fingerprint, localDependencies: try localDependencyFingerprint())
    let previous = (try? Data(contentsOf: fileURL(receipt))).flatMap {
      try? JSONDecoder().decode(BuildRecord.self, from: $0)
    }
    guard previous != expected || !FileManager.default.isExecutableFile(atPath: binary.string)
    else { return }
    try await toolchain.run(arguments, in: directory)
    try JSONEncoder().encode(expected).write(to: fileURL(receipt), options: .atomic)
  }

  private func localDependencyFingerprint() throws -> String {
    var files: [String] = []
    for dependency in analysis.dependencies {
      guard case .local(let path) = dependency.dependencyName else { continue }
      guard
        let enumerator = FileManager.default.enumerator(
          at: fileURL(path),
          includingPropertiesForKeys: [
            .contentModificationDateKey, .fileSizeKey, .isRegularFileKey,
          ], options: [.skipsHiddenFiles])
      else { throw SourceError.invalidDependency(path.string) }
      for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: [
          .contentModificationDateKey, .fileSizeKey, .isRegularFileKey,
        ])
        if values.isRegularFile == true {
          files.append(
            url.path + ":" + String(values.fileSize ?? 0) + ":"
              + String(values.contentModificationDate?.timeIntervalSince1970 ?? 0))
        }
      }
    }
    return digest(files.sorted().joined(separator: "\n"))
  }
}

private struct BuildRecord: Codable, Equatable {
  let arguments: [String]
  let source: String
  let manifest: String
  let toolchain: String
  let localDependencies: String
}

private func writeIfChanged(_ text: String, to path: FilePath) throws {
  guard (try? String(contentsOf: fileURL(path), encoding: .utf8)) != text else { return }
  try text.write(to: fileURL(path), atomically: true, encoding: .utf8)
}
