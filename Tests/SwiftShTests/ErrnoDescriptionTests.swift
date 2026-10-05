// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import Testing

@testable import SwiftSh

@Suite
struct ErrnoDescriptionTests {
  @Test func describesErrorNumbers() {
    #if os(macOS)
      #expect(errnoDescription(ERANGE) == "Result too large (34)")
    #else
      #expect(errnoDescription(ERANGE).hasSuffix("(34)"))
    #endif
  }
}
