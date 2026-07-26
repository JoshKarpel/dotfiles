# Platform Setup for Rust Profiling

Getting `perf` to sample an unprivileged process, on Linux and specifically under
WSL2. Read this when `perf record` or `samply record` fails before it collects
anything.

## Tools

`samply` and `hyperfine` are single prebuilt binaries; install them through mise
rather than `cargo install`, which builds samply from source (minutes, versus
seconds for a release download):

```bash
mise use -g "github:mstange/samply@latest" hyperfine@latest
```

`addr2line` and `nm` come from binutils (`apt install binutils`), and are already
present on most Linux boxes. GNU's demangle Rust symbols more completely than
LLVM's; the report script prefers GNU and falls back to `llvm-addr2line` /
`llvm-nm`, which is what a Mac is likely to have.

## Kernel settings

Two sysctls gate profiling:

- **`kernel.perf_event_paranoid`** decides whether an unprivileged user may sample
  a process it owns at all. It commonly defaults to `2`, which blocks sampling
  outright. `1` is enough.
- **`kernel.perf_event_max_stack`** is how many frames the kernel walks per sample.
  The default of `127` truncates deeply recursive code (regex compilation reaches
  well past it). Raise it to `1024`.

`perf_event_max_stack` **cannot be changed while any perf event is open**, so set it
before recording.

Write both under `/etc/sysctl.d/` so they survive a reboot, and under WSL2 a
shutdown of the VM:

```bash
printf '%s\n' 'kernel.perf_event_paranoid = 1' 'kernel.perf_event_max_stack = 1024' \
  | sudo tee /etc/sysctl.d/99-perf-event.conf > /dev/null
sudo sysctl --system
sysctl kernel.perf_event_paranoid kernel.perf_event_max_stack
```

This needs an interactive `sudo`. Ask the user to run it rather than grinding on a
non-interactive `sudo -n`, which fails for lack of a TTY regardless of permissions.

`kernel.kptr_restrict` only affects *kernel* symbol names. User-space Rust profiling
doesn't need it, so leave it at its restrictive default and accept that kernel time
aggregates into one `[kernel]` bucket.

## WSL2

WSL2 resets sysctls on VM shutdown, not just on reboot. `/etc/sysctl.d/` is read at
boot by `systemd-sysctl`, which only helps if systemd is actually PID 1 in your
distro. Check before relying on it:

```bash
ps -p 1 -o comm=
```

If that isn't `systemd`, enable systemd in `/etc/wsl.conf` or re-apply the sysctls
per session.

### Ubuntu's perf wrapper

`/usr/bin/perf` on Ubuntu is a wrapper that looks for a `perf` build matching the
running kernel and refuses to run when it finds none, which is the case for every
Microsoft-patched WSL2 kernel string:

```text
WARNING: perf not found for kernel 6.18.33.2-microsoft-standard-WSL2
```

The versioned binary the wrapper declines to exec works fine. Fall back to it:

```bash
perf="$(command -v perf || true)"
if [[ -z "$perf" ]] || ! "$perf" --version >/dev/null 2>&1; then
  perf="$(ls /usr/lib/linux-tools/*/perf 2>/dev/null | head -1)"
fi
```

Install it with `sudo apt install linux-tools-generic` if neither exists. Some
setups instead provide a working `/usr/bin/perf` directly, so probe rather than
assuming which case you're in.

## Checking the setup works

A quick end-to-end validation before trusting any numbers:

```bash
RUSTFLAGS="-Cforce-frame-pointers=yes" cargo build --profile profiling
perf record --call-graph fp --freq 2000 -o /tmp/perf.data -- ./target/profiling/mybin ...
samply import /tmp/perf.data --save-only --no-open -o /tmp/profile.json
uv run ${CLAUDE_SKILL_DIR}/scripts/profile_report.py /tmp/profile.json --binary target/profiling/mybin
```

The header line reports the unwind fraction. If it's near 100%, the setup is good.
If it's low and you built with frame pointers, `perf_event_max_stack` is the usual
cause.
