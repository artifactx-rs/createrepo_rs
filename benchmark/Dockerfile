# Reproducible benchmark: createrepo_rs vs createrepo_c
#
#   docker build -t crrs-bench benchmark/
#   docker run --rm crrs-bench            # default: 1000 synthetic packages
#   docker run --rm crrs-bench 500        # custom package count
#
# Both tools run NATIVELY for the build platform, so the numbers are real on
# whatever arch you build on (arm64 Mac, amd64 server, CI). createrepo_rs is
# installed from crates.io with the release profile — the same artifact users
# get from `cargo install` / the published binaries.
FROM fedora:42

# createrepo_c + Rust toolchain to build createrepo_rs + benchmark tooling.
# install_weak_deps=False keeps createrepo_c's dependency closure honest for
# the "shared libs" comparison.
RUN dnf install -y --setopt=install_weak_deps=False \
        createrepo_c \
        cargo rust gcc \
        xz-devel bzip2-devel zlib-devel \
        rpm-build rpmdevtools \
        hyperfine time \
        gzip findutils coreutils diffutils \
    && dnf clean all

# Build createrepo_rs from crates.io (native, --release).
RUN cargo install createrepo_rs --root /usr/local \
    && strip /usr/local/bin/createrepo_rs || true

# Decompression CLIs for the output-equivalence check: createrepo_c 1.2+ emits
# zstd-compressed metadata by default, createrepo_rs may emit gzip.
RUN dnf install -y --setopt=install_weak_deps=False zstd xz && dnf clean all

COPY gen-rpms.sh run.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/gen-rpms.sh /usr/local/bin/run.sh

ENTRYPOINT ["/usr/local/bin/run.sh"]
CMD ["1000"]
