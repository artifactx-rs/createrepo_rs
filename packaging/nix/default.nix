{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "createrepo-rs";
  version = "0.1.8";

  src = fetchFromGitHub {
    owner = "jamesarch";
    repo = "createrepo_rs";
    rev = "v${version}";
    sha256 = ""; # nix-prefetch-url --unpack https://github.com/jamesarch/createrepo_rs/archive/v${version}.tar.gz
  };

  cargoHash = ""; # nix-build -A createrepo-rs 2>&1 | grep cargoHash

  nativeBuildInputs = [ ];

  buildFeatures = [ ];

  meta = with lib; {
    description = "Pure Rust RPM repository metadata generator — dnf/yum-compatible, zero FFI";
    homepage = "https://github.com/jamesarch/createrepo_rs";
    changelog = "https://github.com/jamesarch/createrepo_rs/releases/tag/v${version}";
    license = licenses.gpl2Plus;
    mainProgram = "createrepo_rs";
    maintainers = with maintainers; [ ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
