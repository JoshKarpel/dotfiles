# apt (Debian/Ubuntu)

Install and clean in the same layer:

```dockerfile
RUN <<EOF
set -e
apt-get update
apt-get install -y --no-install-recommends \
  curl \
  ca-certificates
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF
```

- `--no-install-recommends` — skip weak dependencies Docker images don't need.
- `apt-get clean` + `rm -rf /var/lib/apt/lists/*` — clears downloaded packages
  and the package index from the layer.
