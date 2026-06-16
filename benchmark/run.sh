#!/usr/bin/env bash
# Benchmark createrepo_rs against createrepo_c on a synthetic repo.
#
#   run.sh <package-count>      (default 1000)
#
# Reports: static footprint (binary size, shared libs), wall-clock (hyperfine),
# peak RSS, and output equivalence (package-checksum set must be identical).
set -euo pipefail

N="${1:-1000}"
REPO=/repo
rm -rf "$REPO"; mkdir -p "$REPO"

gen-rpms.sh "$N" "$REPO"

cbin="$(command -v createrepo_c)"
rbin="$(command -v createrepo_rs)"

# Parallelism: createrepo_rs uses all cores by default. createrepo_c defaults
# to 5 workers but accepts --workers 1..100, so for an apples-to-apples
# wall-clock we also run it at $(nproc) workers — createrepo_c is NOT pinned
# to its 5-worker default here.
NPROC="$(nproc)"

echo
echo "================ Environment ================"
echo "arch:          $(uname -m)"
echo "CPUs:          $NPROC"
echo "createrepo_c:  $(createrepo_c --version 2>&1 | head -1)"
echo "createrepo_rs: $(createrepo_rs --version 2>&1 | head -1)"

# ---- static footprint ----
cdeps="$(ldd "$cbin" 2>/dev/null | grep -c '=>' || true)"
rdeps="$(ldd "$rbin" 2>/dev/null | grep -c '=>' || true)"
csize="$(du -h "$cbin" | cut -f1)"
rsize="$(du -h "$rbin" | cut -f1)"

echo
echo "================ Static footprint ================"
printf "%-16s %-14s %-14s\n" ""            "createrepo_c" "createrepo_rs"
printf "%-16s %-14s %-14s\n" "binary size" "$csize"       "$rsize"
printf "%-16s %-14s %-14s\n" "shared libs" "$cdeps"       "$rdeps"

# ---- wall-clock ----
# Three columns so nobody can claim createrepo_c was sandbagged:
#   createrepo_c            — its out-of-the-box default (5 workers)
#   createrepo_c -w NPROC   — matched parallelism (same core budget as rs)
#   createrepo_rs           — default (all cores)
echo
echo "================ Wall-clock ($N pkgs, 5 runs) ================"
hyperfine -w1 -r5 \
  --prepare "rm -rf $REPO/repodata" \
  --command-name "createrepo_c (default 5w)"   "createrepo_c $REPO" \
  --command-name "createrepo_c (-w $NPROC)"    "createrepo_c --workers $NPROC $REPO" \
  --command-name "createrepo_rs (all cores)"   "createrepo_rs $REPO"

# ---- peak RSS ----
echo
echo "================ Peak RSS ================"
rm -rf "$REPO/repodata"
cmem="$(/usr/bin/time -v createrepo_c --workers "$NPROC" "$REPO" 2>&1 | awk '/Maximum resident/{print $NF}')"
rm -rf "$REPO/repodata"
rmem="$(/usr/bin/time -v createrepo_rs "$REPO" 2>&1 | awk '/Maximum resident/{print $NF}')"
printf "createrepo_c:  %'d KB\ncreaterepo_rs: %'d KB\n" "$cmem" "$rmem" 2>/dev/null \
  || printf "createrepo_c:  %s KB\ncreaterepo_rs: %s KB\n" "$cmem" "$rmem"

# ---- output equivalence (package-checksum set) ----
# Decompress primary.xml regardless of compression (gzip / zstd / xz).
extract_primary() {
  local f
  f="$(find "$1/repodata" -name '*primary.xml*' -type f | head -1)"
  case "$f" in
    *.zst) zstd -dc "$f" ;;
    *.xz)  xz -dc "$f" ;;
    *.gz)  gzip -dc "$f" ;;
    *)     cat "$f" ;;
  esac
}

echo
echo "================ Output equivalence ================"
rm -rf "$REPO/repodata"; createrepo_c  "$REPO" >/dev/null 2>&1
extract_primary "$REPO" | grep -oE '[a-f0-9]{64}' | sort -u > /tmp/c.ids
rm -rf "$REPO/repodata"; createrepo_rs "$REPO" >/dev/null 2>&1
extract_primary "$REPO" | grep -oE '[a-f0-9]{64}' | sort -u > /tmp/r.ids
if diff -q /tmp/c.ids /tmp/r.ids >/dev/null; then
  echo "✓ IDENTICAL package-checksum set ($(wc -l < /tmp/c.ids) packages) — outputs are equivalent"
else
  echo "✗ DIFFER: $(comm -3 /tmp/c.ids /tmp/r.ids | wc -l) mismatched checksums"
  echo "  (createrepo_c only / createrepo_rs only shown below)"
  comm -3 /tmp/c.ids /tmp/r.ids | head
fi
