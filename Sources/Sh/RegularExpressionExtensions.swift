import var Foundation.NSNotFound
import struct Foundation.NSRange
import class Foundation.NSRegularExpression
import class Foundation.NSTextCheckingResult

extension NSRegularExpression {
  public func firstMatch(in str: String) -> NSTextCheckingResult? {
    let range = NSRange(location: 0, length: str.utf16.count)
    return firstMatch(in: str, range: range)
  }
}

extension NSTextCheckingResult {
  public func isMatch(at: Int) -> Bool {
    guard at < numberOfRanges else { return false }
    return range(at: at).location != NSNotFound
  }
}

extension String {
  public subscript(range: NSRange) -> Substring {
    return self[Range(range, in: self)!]
  }
}
