// SPDX-License-Identifier: Unlicense

func run(_ input: Mode.RunType, arguments: [String]) async throws -> Never {
  let analysis = try ScriptAnalysis(source: ScriptSource(reading: input))
  let cache = BuildCache()
  let lock = try CacheLock(root: cache.root, key: cache.key(for: analysis.source))
  defer { lock.release() }
  let toolchain = try await SwiftToolchain.discover(cache: cache)
  let script = Script(analysis: analysis, cache: cache)
  try await script.build(using: toolchain)
  try exec(arg0: script.binary.string, args: arguments)
}
