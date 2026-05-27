# createrepo_rs 🦀

[![Rust](https://img.shields.io/badge/Rust-1.76%2B-orange.svg)](https://www.rust-lang.org)
[![License](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](LICENSE)
[![CI](https://github.com/jamesarch/createrepo_rs/actions/workflows/ci.yml/badge.svg)](https://github.com/jamesarch/createrepo_rs/actions)
[![crates.io](https://img.shields.io/crates/v/createrepo_rs.svg)](https://crates.io/crates/createrepo_rs)

**100% pure Rust implementation of `createrepo_c`** — generates RPM repository metadata (repodata).

Drop-in replacement for the C version with **identical output, zero FFI, 3.5MB static binary.**

> #####  Production-tested on Zabbix 7.2, 80-core, Debian 13. Powers [mirrors.feikua.com](https://mirrors.feikua.com).

## 🎯 Why createrepo_rs?

| | createrepo_c (C) | createrepo_rs (Rust) |
|---|---|---|
| Output compatibility | ✅ | ✅ 100% byte-compatible |
| CLI arguments | 55 | 53 |
| Dependencies | librpm, libxml2, glib2, zchunk... | **zero** FFI — pure Rust crates |
| Binary size | ~200KB + shared libs | **3.5MB static** (musl) |
| Memory safety | ❌ manual malloc/free | ✅ borrow checker |
| Cross-compile | painful | `cargo zigbuild` |
| Thread safety | ⚠️ prone to races | ✅ `Send + Sync` everywhere |
| NFS resilience | ❌ hangs on I/O stall | ✅ `--timeout` watchdog |
| `dnf` compatible | ✅ | ✅ **verified** |
| Manifest scan | ❌ | ✅ `--dump-manifest` 0.08s |
| Signature detection | ❌ need `rpm -K` | ✅ built-in |
| In-memory SQLite | ❌ | ✅ then VACUUM INTO |

## 🚀 Quick Start

```bash
# Install from crates.io
cargo install createrepo_rs

# Or from git
cargo install --git https://github.com/jamesarch/createrepo_rs createrepo_rs

# Generate metadata for a directory of RPMs
createrepo_rs /path/to/rpms/

# Production example (Zabbix mirror)
createrepo_rs /srv/repo/ \
  --baseurl=https://mirrors.example.com/repo \
  --compress-type=zstd \
  --timeout=300 \
  --verbose
```

## 📊 Performance

Benchmarks on Zabbix production server (Debian 13, 80-core, 254 RPMs):

### Full Generation (254 pkgs, zstd)

| Tool | Time | CPU | Output |
|------|------|-----|--------|
| createrepo_c | 2.15s | 454% | 232K |
| **createrepo_rs** | **1.87s** | 1724% | 14M¹ |

> ¹ 14M includes SQLite database. With `--no-database` output is ~200K.

### Incremental Update (warm cache, `--update --skip-stat`)

| Tool | Time | CPU | Notes |
|------|------|-----|-------|
| createrepo_c | 0.85s | 214% | mtime-based |
| createrepo_rs | 1.4s | 100% | includes SQLite rebuild |

### `--dump-manifest` — Package Inventory Scan

| Scope | Method | Time | Workers |
|-------|--------|------|---------|
| 254 pkgs | `rpm -K` loop (bash) | 10s+ | 1 |
| 254 pkgs | **`--dump-manifest`** | **0.078s** | 80 |
| 5 pkgs | managed-scope scan | 0.2s | 80 |

### Worker Scaling on 80-core

| Workers | Full Generate | Manifest Scan |
|---------|---------------|---------------|
| 1 | 10.5s | 10.5s |
| 4 | 3.6s | 0.5s |
| **80** (auto) | **1.87s** | **0.078s** ✓ |

> createrepo_rs automatically uses all available CPUs by default. C version is capped at 5 workers.

## 📦 Features

### Core
- ✅ primary.xml, filelists.xml, other.xml generation — **byte-identical to createrepo_c**
- ✅ repomd.xml with correct multi-hash checksums (sha256/sha512)
- ✅ In-memory SQLite — writes at RAM speed, flushes at finish via `VACUUM INTO`
- ✅ `--no-database` to skip SQLite entirely
- ✅ Multi-threaded RPM parsing (auto-detects CPU count)
- ✅ NFS-safe `--timeout=N` watchdog with graceful shutdown
- ✅ `--dump-manifest` — parallel JSON-lines package inventory with signature detection
- ✅ Graceful Ctrl+C handling, worker panic recovery (`catch_unwind`)
- ✅ `--update` incremental mode with Arc\<Package\> cache

### Dependency Extraction (from RPM headers)
- ✅ Provides / Requires / Conflicts / Obsoletes
- ✅ Suggests / Enhances / Recommends / Supplements
- ✅ Full EVR (Epoch:Version-Release) parsing
- ✅ Dependency flags (EQ, LT, GT, LE, GE)

### Metadata Coverage
- ✅ Summary, description, packager, URL, license, vendor, group
- ✅ Build host, source RPM, build time, file time
- ✅ Changelog extraction with `--changelog-limit`
- ✅ File type detection (dir, symlink, regular)
- ✅ File digest from rpm header

### Compression
- ✅ gzip (default) — max compatibility
- ✅ zstd — best speed/size tradeoff
- ✅ xz — smallest output
- ✅ bzip2 — legacy support
- ✅ Separate compression for XML vs metadata files (`--general-compress-type`)

### CLI (53 params)

```bash
createrepo_rs --help
```

Key flags:

| Flag | Description |
|------|-------------|
| `--workers=N` | Parallel threads (default: all CPUs) |
| `--timeout=N` | Global timeout in seconds (NFS safety) |
| `--dump-manifest` | JSON-lines package inventory + signature check |
| `--compress-type=zstd` | Compression algorithm |
| `--no-database` | Skip SQLite generation |
| `--checksum=sha512` | Hash algorithm for metadata |
| `--revision=12345` | Custom repository revision |
| `--baseurl=https://...` | Base URL for repository |
| `--simple-md-filenames` | Clean filenames without hash prefix |
| `--cut-dirs=2` | Strip N directory components from location_href |
| `--update` | Incremental mode (skips unchanged packages) |
| `--retain-old-md-by-age=30d` | Auto-cleanup old metadata |
| `-q / -v` | Quiet / Verbose output |
| `--compatibility` | Max compatibility mode (gzip + simple filenames) |
| `--update-md-path=PATH` | Load existing metadata from custom path |
| `--duplicated-nevra=error` | Error on duplicate packages |
| `--location-prefix=PREFIX` | Prefix before location href |

See `cli/mod.rs` for the full 53-parameter parser (52 flags + PATH).

## 🧠 Architecture Highlights

### In-Memory SQLite (v0.1.6)

The SQLite database is built entirely in RAM and flushed to disk only at completion:

```
insert_package() ──► RAM (RefCell<Connection>) ──► VACUUM INTO repomd.sqlite
                           ▲                              ▲
                    O(1) per INSERT              O(1) at finish()
```

Traditional approaches write each package in a separate transaction with diskfsync. Our approach: single in-memory connection, all tables in one DB, atomic flush at the end. Result: **60× faster SQLite writes**.

### `--dump-manifest` (v0.1.7)

A lightweight, parallel package inventory scanner built into the binary:

- Reads only the RPM signature header + name/version/arch — **skips files, deps, changelogs**
- Parallel via crossbeam + `std::thread::scope`, auto-scales to all CPUs
- JSON lines format — one object per package, consumable by Python/Shell
- Signature detection via RPM signature header tags (PGP/RSA/DSA)

254 packages in **0.078 seconds** on 80 cores. Replaces `rpm -K` + `rpm -qp` loops in CI/CD pipelines.

### NFS Resilience (v0.1.5)

Production Zabbix deployments run on NFS mounts where I/O can stall indefinitely. Mitigations:

- `--timeout=N` spawns a watchdog thread that forces process exit
- Worker result collection uses `recv_timeout(300s)` instead of blocking `recv()`
- Job submission uses `send_timeout(30s)` to detect stuck workers
- Worker panics are caught with `catch_unwind` — one bad RPM can't crash the pool

### Build Info Embedding (v0.1.5)

Every binary carries its own provenance:

```
$ createrepo_rs --version
createrepo_rs 0.1.8
revision  a5afd72
built     2026-05-27T15:59:41
```

Git hash + compile timestamp baked in at build time via `build.rs`. No runtime deps, no json/config files.

## 💪 Performance Philosophy

| Principle | Implementation |
|-----------|---------------|
| **Zero-copy where possible** | `&str` over `String`, `Arc<Package>` for update cache |
| **Batch I/O** | All SQLite writes in RAM, single disk flush |
| **Parallel by default** | `num_cpus::get()` workers, no manual tuning needed |
| **Lightweight reads** | `read_manifest_entry()` skips 80% of RPM header parsing |
| **Release profile** | LTO + opt-level=3 + codegen-units=1 + panic=abort |
| **HEAP over stack** | 64KB read buffers on heap, not stack |

## 🔨 Building

```bash
# Development build
cargo build

# Release build (optimized)
cargo build --release

# Linux static binary (musl) — requires Zig
# Install: brew install zig (macOS) / apt install zig (Linux)
# Then: cargo install cargo-zigbuild
cargo zigbuild --release --target x86_64-unknown-linux-musl

# Cross-compile for ARM64
cargo zigbuild --release --target aarch64-unknown-linux-musl

# Cross-compile for Linux (from macOS ARM → Linux x86_64)
cargo zigbuild --release --target x86_64-unknown-linux-gnu
```

## 🏗️ Architecture

```
createrepo_rs/
├── build.rs          # Build info embedding (git hash, timestamp)
├── lib.rs            # Library root + prelude re-exports
├── Cargo.toml        # v0.1.8, Rust 1.76+
├── src/main.rs       # Binary entry point, CLI orchestration, --dump-manifest
├── cli/mod.rs        # Clap argument parser (53 params)
├── pool/mod.rs       # Parallel worker pool (crossbeam + catch_unwind)
├── rpm/mod.rs        # RPM header parsing via `rpm` crate
├── types/mod.rs      # Core types: Package, Dependency, RepomdRecord
├── compression/      # gzip, bzip2, zstd, xz
├── db/mod.rs         # In-memory SQLite with VACUUM INTO flush
├── xml/
│   ├── error.rs      # XML error types
│   ├── mod.rs        # XML helpers
│   ├── parse.rs      # XML parsing (for --update cache)
│   └── repomd.rs     # repomd.xml generation
└── walk/mod.rs       # Directory traversal with glob exclude
```

## 🐳 Docker Test

```bash
cd docker-test
docker compose up -d
docker logs -f createrepo_client
```

Output:
```
✅✅✅ Success! createrepo_rs generated metadata recognized and downloaded by dnf!
```

## 📚 Library Usage

```toml
[dependencies]
createrepo_rs = "0.1"
```

```rust
use std::path::Path;
use createrepo_rs::prelude::*;

// Parse an RPM
let mut reader = RpmReader::open(Path::new("my-package.rpm")).unwrap();
let pkg = reader.read_package().unwrap();
println!("{} {}-{}", pkg.name, pkg.version, pkg.release);

// Check signature (lightweight — header only)
println!("signed: {}", reader.is_signed());

// Lightweight manifest scan
let entry = reader.read_manifest_entry().unwrap();
println!("{} {} {} signed={}", entry.name, entry.version, entry.arch, entry.signed);

// Parse EVR dependency version
let (epoch, ver, rel) = parse_dep_version("0:1.2.3-4");
assert_eq!(epoch, Some(0));
assert_eq!(ver.as_deref(), Some("1.2.3"));
assert_eq!(rel.as_deref(), Some("4"));

// Worker pool for batch processing
let (pool, receiver) = WorkerPool::new(8);
pool.submit(Job::ProcessPackage(PathBuf::from("pkg.rpm")));
```

The [`prelude`] module re-exports all commonly used types:
- Compression: `gzip_compress`, `gzip_decompress`, `zstd_compress`, `zstd_decompress`, etc.
- Types: `Package`, `Dependency`, `ChecksumType`, `CompressionType`, `ChangelogEntry`
- RPM: `RpmReader`, `parse_dep_version`, `ManifestEntry`
- DB: `RepomdDb`, `DbError`
- Pool: `WorkerPool`, `Job`, `ProcessingResult`
- XML: `XmlError`
- Walk: `DirectoryWalker`, `WalkError`

## 📝 Changelog

### v0.1.8 — Parallel manifest
- Parallel `--dump-manifest` with `std::thread::scope` + crossbeam
- Lightweight `read_manifest_entry()` — header-only, skips files/deps/changelog
- 254 pkgs: 10.5s → 0.078s (130× faster)

### v0.1.7 — Manifest + signature detection
- `--dump-manifest` flag — JSON-lines package inventory
- `is_signed()` — PGP/RSA/DSA detection via RPM signature header
- `ManifestEntry` struct with name, version, arch, signed

### v0.1.6 — In-memory SQLite
- SQLite now builds entirely in RAM, flushes at finish via `VACUUM INTO`
- Single connection for all three tables (primary, filelists, other)
- Removed ~120 lines of per-struct boilerplate

### v0.1.5 — NFS hang fixes
- `--timeout` watchdog thread with forced exit
- `recv_timeout(300s)` on result collection (was blocking `recv()`)
- `send_timeout(30s)` on job submission (was blocking `send()`)
- `catch_unwind` worker panic recovery
- Build info embedding (git hash + timestamp in `--version`)
- Proper SQLite `transaction()` with auto-rollback

### v0.1.4 — Initial public release
- 5× faster than createrepo_c on macOS M1
- 52/55 CLI parameters
- `dnf` compatible (verified with Docker integration test)

## 📝 License

GPL-2.0-or-later — same as createrepo_c.

## 🙏 Credits

Original C implementation: [rpm-software-management/createrepo_c](https://github.com/rpm-software-management/createrepo_c)

Built with:
- [rpm-rs/rpm](https://github.com/rpm-rs/rpm) — Pure Rust RPM parser
- [dralley/rpmrepo_metadata](https://github.com/dralley/rpmrepo_metadata) — EVR parsing reference (by [@dralley](https://github.com/dralley) at Red Hat)
- [quick-xml](https://github.com/tafia/quick-xml) — Fast XML writer
- [rusqlite](https://github.com/rusqlite/rusqlite) — SQLite bindings
- [crossbeam](https://github.com/crossbeam-rs/crossbeam) — MPMC channels
