import Testing

func expect(_ condition: @autoclosure () -> Bool, line: UInt = #line) {
  #expect(condition(), "line \(line)")
}

func expectFalse(_ condition: @autoclosure () -> Bool, line: UInt = #line) {
  #expect(!condition(), "line \(line)")
}

func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T, line: UInt = #line) {
  #expect(lhs == rhs, "line \(line)")
}

func expectEqual<T: Equatable>(_ lhs: T?, _ rhs: T, line: UInt = #line) {
  #expect(lhs == .some(rhs), "line \(line)")
}

func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T?, line: UInt = #line) {
  #expect(.some(lhs) == rhs, "line \(line)")
}

func expectNotNil<T>(_ value: @autoclosure () -> T?, line: UInt = #line) {
  #expect(value() != nil, "line \(line)")
}

func expectThrows(_ body: @autoclosure () throws -> Any, line: UInt = #line) {
  do {
    _ = try body()
    fail("Expected error", line: line)
  } catch {
  }
}

func expectNoThrow(_ body: @autoclosure () throws -> Any, line: UInt = #line) {
  do {
    _ = try body()
  } catch {
    fail("Unexpected error: \(error)", line: line)
  }
}

func fail(_ message: String, line: UInt = #line) {
  #expect(Bool(false), "\(message) (line \(line))")
}
