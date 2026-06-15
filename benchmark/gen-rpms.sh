#!/usr/bin/env bash
# Generate N synthetic RPMs into an output directory.
#
# Deterministic and reproducible: package N always yields the same NEVRA and
# the same payload, so the resulting repo (and its package checksums) is stable
# across runs and machines.
#
#   gen-rpms.sh <count> <out-dir>
set -euo pipefail

N="${1:-1000}"
OUT="${2:-/repo}"
mkdir -p "$OUT"

TOP="$(mktemp -d)"
mkdir -p "$TOP"/{BUILD,RPMS,SOURCES,SPECS,BUILDROOT}

# A fixed payload so package checksums are reproducible.
printf 'createrepo benchmark synthetic payload\n' > "$TOP/SOURCES/data.txt"

gen_spec() {
  local i="$1"
  cat <<EOF
Name:           bench-pkg-$i
Version:        1.$((i % 20)).$((i % 50))
Release:        $((i % 10))
Summary:        Synthetic benchmark package $i
License:        MIT
BuildArch:      noarch
%description
Synthetic package number $i, generated for the createrepo benchmark.
%install
mkdir -p %{buildroot}/usr/share/bench-pkg-$i
install -m644 %{_sourcedir}/data.txt %{buildroot}/usr/share/bench-pkg-$i/data.txt
%files
/usr/share/bench-pkg-$i/data.txt
EOF
}

echo "Generating $N synthetic RPMs (parallel rpmbuild)..."
for i in $(seq 1 "$N"); do
  gen_spec "$i" > "$TOP/SPECS/p$i.spec"
done

# rpmbuild is fork-per-package; parallelise across all cores.
printf '%s\n' "$TOP"/SPECS/*.spec \
  | xargs -P"$(nproc)" -I{} rpmbuild --quiet --define "_topdir $TOP" -bb {} >/dev/null 2>&1

find "$TOP/RPMS" -name '*.rpm' -exec cp {} "$OUT/" \;
COUNT="$(find "$OUT" -name '*.rpm' | wc -l)"
rm -rf "$TOP"
echo "Done: $COUNT RPMs in $OUT"
