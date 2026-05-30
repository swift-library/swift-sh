import Foundation
import LegibleError

do {
  let isTTY = isatty(fileno(stdin)) == 1
  let mode = try Mode(for: CommandLine.arguments, isTTY: isTTY)

  switch mode {
  case .run(let input, let args):
    try run(input, arguments: args)
  case .package(let path, let force, let move):
    try package(path, force: force, move: move)
  case .open(let path, let xcode):
    try open(path: path, xcode: xcode)
  case .clean(let path):
    try clean(path)
  case .help(let message):
    print(message)
  }
} catch let error as CommandLine.Error {
  fputs(
    """
    error: invalid usage
    \(error.errorDescription ?? CommandLine.usage)\n
    """, stderr)
  exit(3)
} catch {
  fputs("error: \(error.legibleLocalizedDescription)\n", stderr)
  exit(2)
}
