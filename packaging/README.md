# Packaging

Distribution packaging files for createrepo_rs.

## Strategy

| Distro | Priority | Effort | Impact | Status |
|--------|----------|--------|--------|--------|
| Fedora COPR | P0 | Low | RPM ecosystem home | Spec ready |
| Arch AUR | P0 | Low | Easy entry, good visibility | PKGBUILD ready |
| Homebrew | P1 | Low | macOS devs, CI/CD | Formula ready |
| Fedora Official | P1 | Medium | Official RPM distro | Needs review |
| EPEL | P1 | Medium | RHEL/Alma/Rocky users | Same spec |
| openSUSE OBS | P2 | Low | Multi-distro via one spec | Same spec |
| Debian/Ubuntu | P3 | High | Different packaging format | Not started |

## Per-Distro Guide

### Fedora COPR (P0 — easiest RPM entry)

```bash
# Install copr CLI
sudo dnf install copr-cli

# Create a COPR project (one-time)
copr-cli create createrepo-rs \
  --description "Pure Rust RPM repository metadata generator" \
  --chroot fedora-rawhide-x86_64 \
  --chroot fedora-41-x86_64 \
  --chroot epel-9-x86_64

# Build from spec
copr-cli build createrepo-rs packaging/rpm/createrepo-rs.spec

# Users install via:
# sudo dnf copr enable yourusername/createrepo-rs
# sudo dnf install createrepo-rs
```

Path to official Fedora: after COPR proves popularity → submit for package review at bugzilla.redhat.com.

### Arch AUR (P0 — immediate)

```bash
# Prepare release tarball and get checksum
# Update sha256sums in PKGBUILD first:
# cd packaging/aur && makepkg -g

# Submit to AUR
git clone ssh://aur@aur.archlinux.org/createrepo-rs.git
cp packaging/aur/PKGBUILD createrepo-rs/
cd createrepo-rs
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO
git commit -m "Initial import: createrepo-rs 0.1.8"
git push
```

Users install via: `yay -S createrepo-rs` or `paru -S createrepo-rs`.

### Homebrew (P1 — macOS/CI)

```bash
# First, calculate SHA256 of the release tarball:
# curl -sL https://github.com/jamesarch/createrepo_rs/archive/refs/tags/v0.1.8.tar.gz | sha256sum
# Update the sha256 field in packaging/homebrew/createrepo-rs.rb

# Submit to homebrew-core via PR
# Fork homebrew-core, add Formula/c/createrepo-rs.rb, send PR
```

Users install via: `brew install createrepo-rs`.

### Fedora Official (P1 — needs review)

After COPR proves demand, submit for official inclusion:

1. File a "Package Review" bug at bugzilla.redhat.com
2. Use `fedora-review` tool for automated checks
3. Request a sponsor if this is your first Fedora package
4. Once approved, request SCM (dist-git) repo

### EPEL (P1 — Enterprise Linux)

Same spec file works. After Fedora acceptance, request EPEL branches (epel9, epel10).

### openSUSE OBS (P2 — multi-distro for free)

OBS (Open Build Service) can build the same spec for:
- openSUSE Tumbleweed/Leap
- Fedora/RHEL/CentOS
- Debian/Ubuntu (needs separate debian/ packaging)

```bash
# Install osc CLI
# Create OBS project and upload spec
osc checkout home:yourusername
osc mkpac createrepo-rs
cp packaging/rpm/createrepo-rs.spec home:yourusername/createrepo-rs/
osc commit -m "Initial import"
```

### Debian/Ubuntu (P3 — future work)

Needs `debian/` directory with control, rules, changelog. Not started — PRs welcome.

## Releasing a New Version

1. Update version in all files:
   - `packaging/rpm/createrepo-rs.spec`: Version + changelog
   - `packaging/aur/PKGBUILD`: pkgver + sha256sums
   - `packaging/homebrew/createrepo-rs.rb`: url + sha256
2. Push release tag → GitHub Actions builds binary
3. Update COPR build / AUR PKGBUILD / Homebrew formula
