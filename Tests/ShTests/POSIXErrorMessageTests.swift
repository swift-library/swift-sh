import Foundation
import Testing

@testable import Sh

@Suite
struct POSIXErrorMessageTests {
  @Test func testStrerror() {
    #if os(macOS)
      expectEqual(strerror(ERANGE), "Result too large (34)")
    #else
      expect(strerror(ERANGE).hasSuffix("(34)"))
    #endif
  }
}
