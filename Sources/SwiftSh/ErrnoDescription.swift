// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

#if os(Linux)
  import func Glibc.strerror_r
  import var Glibc.EINVAL
  import var Glibc.ERANGE
#else
  import func Darwin.strerror_r
  import var Darwin.EINVAL
  import var Darwin.ERANGE
#endif

/// The system message for `code` followed by the number, such as "Result too large (34)".
func errnoDescription(_ code: Int32) -> String {
  var capacity = 64
  while capacity <= 16 * 1024 {
    var buffer = [CChar](repeating: 0, count: capacity)
    switch strerror_r(code, &buffer, buffer.count) {
    case 0:
      let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
      return "\(String(decoding: bytes, as: UTF8.self)) (\(code))"
    case EINVAL:
      return "unknown error \(code)"
    case ERANGE:
      capacity *= 2
    case let failure:
      return "unknown error \(code) (strerror_r: \(failure))"
    }
  }
  return "unknown error \(code)"
}
