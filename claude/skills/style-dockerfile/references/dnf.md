# dnf / yum (RHEL/Fedora/CentOS/Rocky/Amazon Linux)

Install and clean in the same layer:

```dockerfile
RUN <<EOF
set -e
dnf install -y \
  --setopt=install_weak_deps=False \
  --setopt=tsflags=nodocs \
  curl \
  ca-certificates
dnf clean all
rm -rf /var/cache/dnf
EOF
```

- `--setopt=install_weak_deps=False` — equivalent to apt's `--no-install-recommends`.
- `--setopt=tsflags=nodocs` — skip doc files.
- `dnf clean all` + `rm -rf /var/cache/dnf` — fully purge the metadata and
  package cache from the layer.

Replace `dnf` with `yum` and `/var/cache/dnf` with `/var/cache/yum` on older
RHEL 7/CentOS 7 images.
