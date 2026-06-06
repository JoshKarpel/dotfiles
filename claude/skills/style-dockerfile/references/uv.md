# uv (Python)

Copy uv from its official image rather than installing it, using an `ARG` to
pin the version:

```dockerfile
ARG UV_VERSION=0.7.8
COPY --from=ghcr.io/astral-sh/uv:${UV_VERSION} /uv /uvx /usr/local/bin/
```

Set these env vars once in the image:

```dockerfile
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=0
```

- `UV_COMPILE_BYTECODE=1` — compile `.pyc` files at install time for faster startup.
- `UV_LINK_MODE=copy` — required with cache mounts; Docker layers can't hardlink
  across filesystems.
- `UV_PYTHON_DOWNLOADS=0` — use the image's system Python; don't let uv fetch its own.

If uv is only needed for one `RUN` step and shouldn't exist in the image at
all, mount it temporarily instead of copying it:

```dockerfile
RUN --mount=from=ghcr.io/astral-sh/uv:${UV_VERSION},source=/uv,target=/bin/uv \
    --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev
```

The uv binary is discarded when the step completes — only the installed
packages remain in the layer.

Use `COPY --from` (above) when uv is needed across multiple steps; use the
temporary mount when a single step is all you need.

Use bind mounts for the lockfile/pyproject so they don't create a layer, and a cache
mount so the package cache persists across builds:

```dockerfile
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

COPY . .

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev
```

Run the app by activating the venv via `PATH` rather than `uv run`:

```dockerfile
ENV PATH="/app/.venv/bin:$PATH"
CMD ["my-app"]
```
