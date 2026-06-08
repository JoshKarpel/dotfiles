---
name: style-dockerfile
description: >
  Dockerfile style guide. MUST be invoked when writing or editing any Dockerfile,
  Containerfile, or .dockerfile. Covers base image pinning, the heredoc RUN
  pattern, package-manager hygiene (apt, dnf/yum, uv), multi-stage
  builds, layer-caching order, ENV grouping, BuildKit mounts, non-root USER,
  and exec-form CMD/ENTRYPOINT.
---

# Dockerfile Style Guide

## Adopt Project Conventions First

These are defaults. See `style-programming` for the full principle.
Match what's already in the project before applying anything below.

## BuildKit

BuildKit is assumed available. It ships with Docker Desktop and has been the
default engine since Docker 23. It unlocks heredoc `RUN`, inline `COPY`, and
`--mount` cache/bind mounts.

## Base Images

Use fully-qualified references:

```dockerfile
FROM docker.io/library/python:3.12-slim-bookworm
FROM ghcr.io/joshkarpel/spiel:v0.6.0
```

Prefer a specific version tag over `:latest` for reproducibility.

## RUN Pattern — Heredocs (preferred)

Use heredoc syntax for any multi-command `RUN` step. One heredoc equals one
layer; `set -e` makes failures abort the build:

```dockerfile
RUN <<EOF
set -e
apt-get update
apt-get install -y --no-install-recommends rsync ca-certificates
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF
```

Specify an interpreter for steps that aren't `/bin/sh`:

```dockerfile
RUN <<EOF bash
set -euo pipefail
declare -A opts
opts[key]=value
EOF

RUN <<EOF python3
import json
cfg = {"host": "localhost", "port": 8080}
print(json.dumps(cfg, indent=2))
EOF
```

The embedded shell script follows the `style-shell` skill (safety flags, quoting).

### Inline file creation with COPY heredocs

Create config files during the build without polluting the build context:

```dockerfile
COPY <<"EOF" /etc/app/config.toml
[server]
host = "0.0.0.0"
port = 8080
EOF

COPY --chmod=755 <<"EOF" /usr/local/bin/entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
EOF
```

Quote the delimiter (`<<"EOF"`) to prevent the Dockerfile frontend from
expanding `$variables` inside the heredoc — essential for config files.

## Package Manager Hygiene

Always install **and** clean in the same `RUN`/heredoc layer.
A cleanup in a later layer can't shrink a layer that already committed the cache.

For the per-manager recipes (install flags, cache cleanup, version pinning), read
the file matching the base image:

- apt (Debian/Ubuntu) → [references/apt.md](references/apt.md)
- dnf / yum (RHEL/Fedora/CentOS/Rocky/Amazon Linux) → [references/dnf.md](references/dnf.md)
- uv (Python) → [references/uv.md](references/uv.md)

## Layer Caching Order

Copy dependency manifests first, install, then copy the rest of the source.
Source edits won't bust the expensive dependency layer.

Use bind mounts for the manifests so they don't even create a layer:

```dockerfile
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

COPY . .

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev
```

## Multi-Stage Builds

Use named stages to keep the runtime image minimal:

```dockerfile
ARG UV_VERSION=0.7.8

FROM docker.io/library/python:3.12-bookworm AS build

COPY --from=ghcr.io/astral-sh/uv:${UV_VERSION} /uv /uvx /usr/local/bin/
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=0

WORKDIR /app

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

COPY . .

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --no-editable

FROM docker.io/library/python:3.12-slim-bookworm

RUN <<EOF
set -e
groupadd --gid 1001 app
useradd --uid 1001 --gid app --no-create-home app
EOF

WORKDIR /app
COPY --chown=app:app --from=build /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"
USER app
CMD ["my-app"]
```

The build stage installs dependencies; the slim runtime stage copies only the
venv across — no uv, no build tools, no source.

## ENV

One variable per `ENV` instruction — easier to move, reorder, or delete:

```dockerfile
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=0
```

## Capturing Versions with ARG

Use `ARG` to parameterize tool and dependency versions — define once, override
at build time with `--build-arg`:

```dockerfile
ARG UV_VERSION=0.7.8
COPY --from=ghcr.io/astral-sh/uv:${UV_VERSION} /uv /usr/local/bin/
```

`ARG` values are build-time only and not present in the running container's
environment.

When the version should also be inspectable at runtime (e.g. app version
visible via `docker inspect` or `env`), promote it to `ENV`:

```dockerfile
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
```

Built with:

```bash
docker build --build-arg APP_VERSION=1.2.3 .
```

## BuildKit Mounts

Use `--mount` to bind source trees or cache directories without copying them
into the layer:

```dockerfile
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev
```

- `type=bind`: mounts the build context (or a named stage) read-only; avoids
  a `COPY` that would waste a layer.
- `type=cache`: persistent cache across builds; safe to use for package
  manager caches, `~/.cargo`, etc.

## BuildKit Secrets

Never `COPY` a secret file into the image — it lands in the layer history even
if deleted in a later `RUN`. Use `--mount=type=secret` instead: the secret is
available only during that `RUN` step and never written to any layer.

```dockerfile
RUN --mount=type=secret,id=pypi_token <<EOF
set -e
uv sync --locked --no-dev \
  --index-url "https://user:$(cat /run/secrets/pypi_token)@private.pypi.example.com/simple/"
EOF
```

Secrets are mounted at `/run/secrets/<id>` by default. Pass them at build time:

```bash
docker build --secret id=pypi_token,src=~/.pypi-token .
docker build --secret id=pypi_token,env=PYPI_TOKEN .
```

In a Compose file:

```yaml
services:
  app:
    build:
      secrets:
        - pypi_token
secrets:
  pypi_token:
    environment: PYPI_TOKEN
```

Antipatterns to avoid — all three bake the secret into the image history or
metadata, where `docker history` or `docker inspect` will expose it:

```dockerfile
# bad: visible in `docker history`
ARG PYPI_TOKEN
RUN uv sync --index-url "https://user:${PYPI_TOKEN}@..."

# bad: persisted in image ENV metadata
ENV PYPI_TOKEN=s3cr3t
RUN uv sync --index-url "https://user:${PYPI_TOKEN}@..."

# bad: secret lives in intermediate layer even after rm
COPY .pypi-token /tmp/token
RUN uv sync --index-url "https://user:$(cat /tmp/token)@..." \
 && rm /tmp/token
```

## Non-root USER

Drop privileges before the runtime layer. Create a dedicated group and user:

```dockerfile
RUN <<EOF
set -e
groupadd --gid 1001 app
useradd --uid 1001 --gid app --no-create-home app
EOF

USER app
```

Use `COPY --chown=app:app` when copying in application files the user needs to
own:

```dockerfile
COPY --chown=app:app . /app/
```

## CMD / ENTRYPOINT

Always use exec (JSON-array) form — shell form wraps the process in `/bin/sh -c`
and breaks signal handling:

```dockerfile
# correct
CMD ["my-app"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# avoid
CMD my-app
```

## In-Layer Verification

End a significant install step with a smoke test so a broken install fails the
build, not a running container:

```dockerfile
RUN --mount=type=cache,target=/root/.cache/uv <<EOF
set -e
uv sync --locked --no-dev
python -c "import mypackage; print(mypackage.__version__)"
EOF
```

## References

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Docker Build best practices](https://docs.docker.com/build/building/best-practices/)
- [uv Docker integration guide](https://docs.astral.sh/uv/guides/integration/docker/)
