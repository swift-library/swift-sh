// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

/// Replaces swift-sh with `executable`, which inherits the process ID, file descriptors and
/// working directory. Returns only by throwing.
func replaceProcess(with executable: String, arguments: [String]) throws -> Never {
  // Swift concurrency threads may block signals, and the new image inherits the mask.
  var mask = sigset_t()
  sigemptyset(&mask)
  let maskError = pthread_sigmask(SIG_SETMASK, &mask, nil)
  guard maskError == 0 else { throw ProcessReplacementError.signalMask(errno: maskError) }

  let argv = ([executable] + arguments).map { strdup($0) } + [nil]
  defer { for pointer in argv { free(pointer) } }
  execv(executable, argv)
  throw ProcessReplacementError.exec(executable: executable, errno: errno)
}

enum ProcessReplacementError: LocalizedError {
  case exec(executable: String, errno: Int32)
  case signalMask(errno: Int32)

  var errorDescription: String? {
    switch self {
    case .exec(let executable, let errno):
      return "Cannot run \(executable): \(errnoDescription(errno))"
    case .signalMask(let errno):
      return "Restoring signal delivery failed: \(errnoDescription(errno))"
    }
  }
}
