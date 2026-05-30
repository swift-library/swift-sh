import Foundation
import Path
import StreamReader
import Version

public func package(_ script: Path, force: Bool, move: Bool) throws {
  guard script.isFile else {
    throw CocoaError.error(.fileNoSuchFile)
  }

  let reader = try StreamReader(path: script).makeIterator()
  guard force || reader.next().isShebang else { throw PackageError.notScript }

  let input: Script.Input = .path(script)
  let deps = try reader.compactMap { try ImportSpecification(line: $0, from: input) }
  let name = script.basename(dropExtension: true).capitalized
  let destination = script.parent / name

  try Path.mktemp { tmpdir in
    try runSwiftPackage(
      ["init", "--type", "executable", "--name", name, "--disable-swift-testing"], in: tmpdir)

    let generatedSource = try singleGeneratedSwiftSource(in: tmpdir / "Sources" / name)
    try generatedSource.delete()
    try script.copy(to: generatedSource)

    for dep in deps {
      try addDependency(dep, target: name, in: tmpdir)
    }

    if move {
      let backup = script.parent / "\(name).backup"
      do {
        try script.move(to: backup)
        let result = try tmpdir.move(to: destination)
        print("created: \(result)")
        try backup.delete()
      } catch {
        if backup.exists {
          _ = try? backup.move(to: script)
        }
        throw error
      }
    } else {
      let result = try tmpdir.move(to: destination)
      print("created: \(result)")
    }
  }
}

enum PackageError: LocalizedError {
  case notScript

  var errorDescription: String? {
    switch self {
    case .notScript:
      return "cannot package; not Swift script (override with --force)"
    }
  }
}

private func addDependency(_ dep: ImportSpecification, target: String, in packageRoot: Path) throws
{
  var dependencyArguments = ["add-dependency", dep.dependencyName.urlString]
  dependencyArguments.append(
    contentsOf: dep.dependencyName.packageDependencyArguments(for: dep.constraint))
  try runSwiftPackage(dependencyArguments, in: packageRoot)

  try runSwiftPackage(
    [
      "add-target-dependency",
      dep.importName,
      target,
      "--package",
      dep.dependencyName.packageName ?? dep.importName,
    ], in: packageRoot)
}

private func runSwiftPackage(_ arguments: [String], in cwd: Path) throws {
  let task = Process()
  task.launchPath = Path.swift.string
  task.currentDirectoryPath = cwd.string
  task.arguments = ["package"] + arguments
  _ = try task.runSync(tee: true)
}

private func singleGeneratedSwiftSource(in sourcesDirectory: Path) throws -> Path {
  let files = sourcesDirectory.ls().filter { $0.extension == "swift" }
  guard let file = files.first, files.count == 1 else {
    throw CocoaError.error(.fileReadUnknown)
  }
  return file
}

extension ImportSpecification.DependencyName {
  fileprivate func packageDependencyArguments(for constraint: ImportSpecification.Constraint)
    -> [String]
  {
    switch self {
    case .local:
      return ["--type", "path"]
    case .github, .scp, .url:
      return constraint.swiftPackageAddDependencyArguments
    }
  }
}

extension ImportSpecification.Constraint {
  fileprivate var swiftPackageAddDependencyArguments: [String] {
    switch self {
    case .upToNextMajor(from: let version):
      return ["--from", version.description]
    case .exact(let version):
      return ["--exact", version.description]
    case .ref(let ref):
      return ["--revision", ref]
    case .latest:
      return ["--from", "0.0.0", "--to", "1000000.0.0"]
    }
  }
}

extension Optional where Wrapped == String {
  fileprivate var isShebang: Bool {
    switch self {
    case "#!/usr/bin/swift sh"?:
      return true
    case "#!/usr/bin/env swift sh"?:
      return true
    case "#!/usr/bin/swift-sh"?:
      return true
    case "#!/sbin/swift sh"?:  // unlikely but possible
      return true
    case "#!/bin/swift sh"?:  // unlikely but possible
      return true
    default:
      return false
    }
  }
}
