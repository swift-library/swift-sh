class SwiftSh < Formula
  desc "Scripting with easy zero-conf dependency imports"
  homepage "https://github.com/xudongxu/swift-sh"
  license "Unlicense"

  # This workspace-owned formula builds the local repository instead of the
  # published GitHub source.
  head "file://#{File.expand_path("..", __dir__)}", using: :git

  uses_from_macos "swift" => :build

  def install
    args = if OS.mac?
      ["--disable-sandbox"]
    else
      ["--static-swift-stdlib"]
    end
    system "swift", "build", *args, "-c", "release"
    bin.install ".build/release/swift-sh"
  end

  test do
    (testpath/"test.swift").write <<~SWIFT
      #!/usr/bin/env swift sh
      print("hello")
    SWIFT
    system bin/"swift-sh", "package", "test.swift"
    assert_path_exists testpath/"Test/Package.swift"
  end
end
