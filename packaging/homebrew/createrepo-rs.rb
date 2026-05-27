class CreaterepoRs < Formula
  desc "Pure Rust RPM repository metadata generator — dnf/yum-compatible, zero FFI"
  homepage "https://github.com/jamesarch/createrepo_rs"
  url "https://github.com/jamesarch/createrepo_rs/archive/refs/tags/v0.1.8.tar.gz"
  sha256 "SKIP" # Replace with: curl -sL URL | sha256sum
  license "GPL-2.0-or-later"

  depends_on "rust" => :build

  def install
    system "cargo", "install", "--root", prefix, "--path", "."
  end

  test do
    output = shell_output("#{bin}/createrepo_rs --version 2>&1")
    assert_match "createrepo_rs", output
  end
end
