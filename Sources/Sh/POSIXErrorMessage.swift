// SPDX-License-Identifier: Unlicense

#if os(Linux)
  import func Glibc.strerror_r
  import var Glibc.EINVAL
  import var Glibc.ERANGE
#else
  import func Darwin.strerror_r
  import var Darwin.EINVAL
  import var Darwin.ERANGE
#endif

func strerror(_ code: Int32) -> String {
  var cap = 64
  while cap <= 16 * 1024 {
    var buf = [Int8](repeating: 0, count: cap)
    let err = strerror_r(code, &buf, buf.count)
    if err == EINVAL {
      return "unknown error \(code)"
    }
    if err == ERANGE {
      cap *= 2
      continue
    }
    if err != 0 {
      return "fatal: strerror_r: \(err)"
    }
    let bytes = buf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return "\(String(decoding: bytes, as: UTF8.self)) (\(code))"
  }
  return "fatal: strerror_r: ERANGE"
}
