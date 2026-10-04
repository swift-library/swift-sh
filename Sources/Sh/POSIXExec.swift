// SPDX-License-Identifier: Unlicense

import Foundation

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

func exec(arg0: String, args: [String]) throws -> Never {
  let args = CStringArray([arg0] + args)

  // Concurrency workers can block signals; the executed script needs signal delivery.
  var mask = sigset_t()
  sigemptyset(&mask)
  let error = pthread_sigmask(SIG_SETMASK, &mask, nil)
  guard error == 0 else { throw POSIXError.signalMask(errno: error) }

  guard execv(arg0, args.cArray) != -1 else {
    throw POSIXError.execv(executable: arg0, errno: errno)
  }

  fatalError("Impossible if execv succeeded")
}

enum POSIXError: LocalizedError {
  case execv(executable: String, errno: Int32)
  case signalMask(errno: Int32)

  var errorDescription: String? {
    switch self {
    case .execv(let executablePath, let errno):
      return "execv failed: \(strerror(errno)): \(executablePath)"
    case .signalMask(let errno): return "Restoring signal delivery failed: \(strerror(errno))"
    }
  }
}

private final class CStringArray {
  /// The null-terminated array of C string pointers.
  let cArray: [UnsafeMutablePointer<Int8>?]

  /// Creates an instance from an array of strings.
  init(_ array: [String]) {
    cArray = array.map({ $0.withCString({ strdup($0) }) }) + [nil]
  }

  deinit {
    for case let element? in cArray {
      free(element)
    }
  }
}
