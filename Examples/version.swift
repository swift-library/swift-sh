#!/usr/bin/swift sh
import SemVer  // swift-library/swift-semver == 0.1.1

let version = try Version(parsing: CommandLine.arguments[1])
print(try version.incrementing(.minor))
