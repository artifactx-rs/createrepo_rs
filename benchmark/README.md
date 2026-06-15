# Reproducible benchmark: `createrepo_rs` vs `createrepo_c`

A fully containerised, single-command benchmark. No special hardware, no
pre-existing repo, no network at run time — `docker build` once, `docker run`
to get numbers anyone can reproduce, with **both tools running natively in the
same container** (no cross-environment unfairness, no QEMU emulation).

## Run it

```bash
docker build -t crrs-bench benchmark/
docker run --rm crrs-bench            # 1000 synthetic packages (default)
docker run --rm crrs-bench 2000       # custom package count
```

`createrepo_rs` is installed from crates.io with the release profile (same
artifact as `cargo install`); `createrepo_c` comes from Fedora's `dnf`. Both
run natively for the build arch.

## What it measures

| Metric | How |
|--------|-----|
| Static footprint | binary size + shared-library count (`ldd`) |
| Wall-clock | `hyperfine`, 5 runs, repodata wiped between runs |
| Peak memory | `/usr/bin/time -v` Maximum resident set size |
| Output equivalence | both repos' package-checksum (`pkgid`) sets must be identical |

The package set is synthetic but deterministic: package *N* always produces the
same NEVRA and payload, so checksums are stable across machines and runs.

## Results

Environment: Docker (`fedora:42`), 10-core **aarch64**, createrepo_c **1.2.0**
vs createrepo_rs **0.1.8** (from crates.io). Reproduce with the commands above.

| Metric | createrepo_c | createrepo_rs | Winner |
|--------|--------------|---------------|--------|
| Binary size | 72 KB | 3.9 MB | c (but needs 53 libs) |
| **Shared libraries** | **53** | **5** | **rs (10×+ fewer)** |
| Peak RSS @ 500 pkgs | 82.8 MB | **10.2 MB** | **rs — 8.1× less** |
| Peak RSS @ 1000 pkgs | 83.0 MB | **12.3 MB** | **rs — 6.8× less** |
| Peak RSS @ 2000 pkgs | 86.6 MB | **20.0 MB** | **rs — 4.3× less** |
| Wall-clock @ 500 pkgs | 29.7 ms | 23.4 ms | rs 1.27× |
| Wall-clock @ 1000 pkgs | 40.5 ms | 42.7 ms | c 1.05× |
| Wall-clock @ 2000 pkgs | 70.5 ms | 84.4 ms | c 1.20× |
| Output equivalence | — | ✓ identical pkgid set (all sizes) | tie |

### Honest reading of these numbers

- **Memory is the standout win**: createrepo_rs uses **4–8× less RAM**, and its
  footprint grows slowly while createrepo_c sits flat at ~83 MB regardless of
  size. This matters in constrained CI runners and containers.
- **Footprint / packaging is the other real win**: 5 vs 53 shared libraries,
  one static binary, zero FFI to `librpm`/`libxml2`/`glib2`/`zchunk`.
- **Wall-clock is roughly on par.** On this 10-core box createrepo_c pulls
  slightly ahead as the package count grows. Note createrepo_c hardcodes 5
  worker threads — on many-core machines createrepo_rs (uses all cores) may
  close or reverse this; that needs verification on bigger hardware, so we do
  **not** claim a speed win here.
- **Correctness**: identical package-checksum sets at every size — a true
  drop-in, dnf/yum see the repos as equivalent.

> The headline `--dump-manifest` speedup in the top-level README is measured
> against an `rpm -K` loop, not against createrepo_c's metadata generation —
> different operation, don't conflate the two.

## Legacy split-environment scripts

The older `generate_rpms.sh` / `run_bench_rs.sh` / `run_bench_c.sh` /
`compare.sh` ran createrepo_rs on the host and createrepo_c in Docker — two
different environments, so their numbers aren't directly comparable. Prefer the
single-container `Dockerfile` + `run.sh` above for fair, reproducible results.
