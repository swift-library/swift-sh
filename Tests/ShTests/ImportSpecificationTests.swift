import Foundation
import Path
import Testing
import Version

@testable import Sh

@Suite
struct ImportSpecificationTests {
  @Test func testWigglyArrow() throws {
    let a = try parse("import Foo // @example ~> 1.0", from: .path(Path.cwd.join("script.swift")))
    expectEqual(a?.dependencyName, .github(user: "example", repo: "Foo"))
    expectEqual(a?.constraint, .upToNextMajor(from: .one))
    expectEqual(a?.importName, "Foo")
  }

  @Test func testTrailingWhitespace() throws {
    let a = try parse("import Foo // @example ~> 1.0 ", from: .path(Path.cwd.join("script.swift")))
    expectEqual(a?.dependencyName, .github(user: "example", repo: "Foo"))
    expectEqual(a?.constraint, .upToNextMajor(from: .one))
    expectEqual(a?.importName, "Foo")
  }

  @Test func testExact() throws {
    let a = try parse("import Foo // @example == 1.0", from: .path(Path.cwd.join("script.swift")))
    expectEqual(a?.dependencyName, .github(user: "example", repo: "Foo"))
    expectEqual(a?.constraint, .exact(.one))
    expectEqual(a?.importName, "Foo")
  }

  @Test func testMoreSpaces() throws {
    let b = try parse(
      "import    Foo       //     @example    ~>      1.0",
      from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .github(user: "example", repo: "Foo"))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Foo")
  }

  @Test func testMinimalSpaces() throws {
    let b = try parse("import Foo//@example~>1.0", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .github(user: "example", repo: "Foo"))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Foo")
  }

  @Test func testCanOverrideImportName() throws {
    let b = try parse(
      "import Foo  // example/Bar ~> 1.0", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .github(user: "example", repo: "Bar"))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Foo")
  }

  @Test func testCanOverrideImportNameUsingNameWithHyphen() throws {
    let b = try parse(
      "import Bar  // example/swift-bar ~> 1.0", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .github(user: "example", repo: "swift-bar"))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Bar")
  }

  @Test func testCanProvideLocalPath() throws {
    let homePath = Path.home
    let b = try parse(
      "import Bar  // \(homePath.string)", from: .path(homePath.join("script.swift")))
    expectEqual(b?.dependencyName, .local(Path(homePath)))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.packageLine, ".package(path: \"\(homePath.string)\")")
  }

  @Test func testCanProvideLocalPathWithTilde() throws {
    let homePath = Path.home
    let b = try parse("import Bar  // ~/", from: .path(homePath.join("script.swift")))
    expectEqual(b?.dependencyName, .local(Path(homePath)))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.packageLine, ".package(path: \"\(homePath.string)\")")
  }

  @Test func testCanProvideLocalRelativeCurrentPath() throws {
    let cwd = Path.cwd
    let b = try parse("import Bar  // ./", from: .path(cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .local(Path(cwd)))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.packageLine, ".package(path: \"\(cwd.string)\")")
  }

  @Test func testCanProvideLocalRelativeNonCurrentPath() throws {
    let homePath = Path.home
    // Provide a script path that's inside the home directory (not cwd)
    let b = try parse("import Bar  // ./", from: .path(homePath.join("script.swift")))
    expectEqual(b?.dependencyName, .local(Path(homePath)))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.packageLine, ".package(path: \"\(homePath.string)\")")
  }

  @Test func testCanProvideLocalRelativeParentPath() throws {
    let cwdParent = Path.cwd / "../"
    let b = try parse("import Bar  // ../", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .local(cwdParent))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.packageLine, ".package(path: \"\(cwdParent.string)\")")
  }

  @Test func testCanProvideLocalRelativeTwoParentsUpPath() throws {
    let cwdParent = Path.cwd / "../../"
    let b = try parse("import Bar  // ../../", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .local(cwdParent))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.packageLine, ".package(path: \"\(cwdParent.string)\")")
  }

  @Test func testCanProvideLocalPathWithHypen() throws {
    let tmpPath = Path.root.tmp.fake / "with-hyphen-two" / "lastone"
    try tmpPath.mkdir(.p)
    let b = try parse(
      "import Foo  // /tmp/fake/with-hyphen-two/lastone",
      from: .path(tmpPath.join("script.swift")))
    expectEqual(b?.dependencyName, .local(tmpPath))
    expectEqual(b?.importName, "Foo")
    expectEqual(b?.packageLine, ".package(path: \"\(tmpPath.string)\")")
  }

  @Test func testCanProvideLocalPathWithHyphenAndDotsAndSpacesOhMy() throws {
    let tmpPath = Path.root.tmp.fake / "with-hyphen.two.one-zero" / "last one"
    try tmpPath.mkdir(.p)
    let b = try parse(
      "import Foo  // /tmp/fake/with-hyphen.two.one-zero/last one",
      from: .path(tmpPath.join("script.swift")))
    expectEqual(b?.dependencyName, .local(tmpPath))
    expectEqual(b?.importName, "Foo")
    expectEqual(b?.packageLine, ".package(path: \"\(tmpPath.string)\")")
  }

  @Test func testCanProvideLocalPathWithSpaces() throws {
    let tmpPath = Path.root.tmp.fake / "with space" / "last"
    try tmpPath.mkdir(.p)
    let b = try parse(
      "import Bar  // /tmp/fake/with space/last", from: .path(tmpPath.join("script.swift")))
    expectEqual(b?.dependencyName, .local(tmpPath))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.packageLine, ".package(path: \"\(tmpPath.string)\")")
  }

  @Test func testCanProvideLocalPathWithSpacesInLast() throws {
    let tmpPath = Path.root.tmp.fake / "with space" / "last one"
    try tmpPath.mkdir(.p)
    let b = try parse(
      "import Foo  // /tmp/fake/with space/last one",
      from: .path(tmpPath.join("script.swift")))
    expectEqual(b?.dependencyName, .local(tmpPath))
    expectEqual(b?.importName, "Foo")
    expectEqual(b?.packageLine, ".package(path: \"\(tmpPath.string)\")")
  }

  @Test func testCanProvideLocalPathWithSpacesAndRelativeParentsUp() throws {
    let tmpPath = Path.root.tmp.fake.fakechild / ".." / "with space" / "last"
    try tmpPath.mkdir(.p)
    let b = try parse(
      "import Bar  // /tmp/fake/with space/last", from: .path(tmpPath.join("script.swift")))
    expectEqual(b?.dependencyName, .local(tmpPath))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.packageLine, ".package(path: \"\(tmpPath.string)\")")
  }

  @Test func testCanProvideLocalPathWithSpacesAndRelativeParentsUpTwo() throws {
    let tmpPath = Path.root.tmp.fake.fakechild1.fakechild2 / "../.." / "with space" / "last"
    try tmpPath.mkdir(.p)
    let b = try parse(
      "import Bar  // /tmp/fake/with space/last", from: .path(tmpPath.join("script.swift")))
    expectEqual(b?.dependencyName, .local(tmpPath))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.packageLine, ".package(path: \"\(tmpPath.string)\")")
  }

  @Test func testCanProvideFullURL() throws {
    let b = try parse(
      "import Foo  // https://example.com/example/Bar.git ~> 1.0",
      from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .url(URL(string: "https://example.com/example/Bar.git")!))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Foo")
  }

  @Test func testCanProvideFullURLWithHyphen() throws {
    let b = try parse(
      "import Bar  // https://example.com/example/swift-bar.git ~> 1.0",
      from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .url(URL(string: "https://example.com/example/swift-bar.git")!))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Bar")
  }

  @Test func testCanProvideFullSSHURLWithHyphen() throws {
    let url = "ssh://git@github.com/MariusCiocanel/swift-sh.git"
    let b = try parse(
      "import Bar  // \(url) ~> 1.0", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .url(URL(string: url)!))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.dependencyName.urlString, url)
  }

  @Test func testCanProvideCommonSSHURLStyle() throws {
    let uri = "git@github.com:MariusCiocanel/Path.swift.git"
    let b = try parse(
      "import Path  // \(uri) ~> 1.0", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .scp(uri))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Path")
    expectEqual(b?.dependencyName.urlString, "git@github.com:MariusCiocanel/Path.swift.git")
  }

  @Test func testCanProvideCommonSSHURLStyleWithHyphen() throws {
    let uri = "git@github.com:MariusCiocanel/swift-sh.git"
    let b = try parse(
      "import Bar  // \(uri) ~> 1.0", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .scp(uri))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Bar")
    expectEqual(b?.dependencyName.urlString, "git@github.com:MariusCiocanel/swift-sh.git")
  }

  @Test func testCanDoSpecifiedImports() throws {
    let kinds = [
      "struct",
      "class",
      "enum",
      "protocol",
      "typealias",
      "func",
      "let",
      "var",
    ]
    for kind in kinds {
      let b = try parse(
        "import \(kind) Foo.bar  // https://example.com/example/Bar.git ~> 1.0",
        from: .path(Path.cwd.join("script.swift")))
      expectEqual(b?.dependencyName, .url(URL(string: "https://example.com/example/Bar.git")!))
      expectEqual(b?.constraint, .upToNextMajor(from: .one))
      expectEqual(b?.importName, "Foo")
    }
  }

  @Test func testCanUseTestable() throws {
    let b = try parse(
      "@testable import Foo  // @bar ~> 1.0", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .github(user: "bar", repo: "Foo"))
    expectEqual(b?.constraint, .upToNextMajor(from: .one))
    expectEqual(b?.importName, "Foo")
  }

  @Test func testLatestVersion() throws {
    let b = try parse("import Foo  // @bar", from: .path(Path.cwd.join("script.swift")))
    expectEqual(b?.dependencyName, .github(user: "bar", repo: "Foo"))
    expectEqual(b?.constraint, .latest)
    expectEqual(b?.importName, "Foo")
  }

  @Test func testSwiftVersion() {
    let components = swiftVersion.split(separator: ".")
    expectEqual(components.count, 2)
    expectNotNil(Int(components[0]))
    expectNotNil(Int(components[1]))
  }
}

extension Version {
  static var one: Version {
    return Version(1, 0, 0)
  }
}
