# Configuration

Secrets are out of scope here; they have their own sourcing and handling
constraints, covered in the secrets style guide.

## Parse at the Boundary

Read and validate configuration once, where it enters the process, into a single
typed object. Don't scatter raw `os.environ` lookups or re-parse the same file
throughout the code. A typed config object makes missing or malformed settings
fail loudly at startup rather than at first use, and hands the rest of the code
already-valid values. Reach for a settings library that parses into a validated
type rather than reading raw values yourself (in Python, for example,
`pydantic-settings`). This is the parse-don't-validate rule applied to
configuration.

## Dynamic Reload Is the App's Responsibility

A platform that delivers updated config (a Kubernetes `ConfigMap`/`Secret`
directory mount, a config service, a watched file) only updates the *source*. A
running process keeps using whatever it loaded until it reads again. Mounting
config so it updates in place does nothing on its own.

Decide deliberately, per setting, how a change takes effect:

- **Watch the source for changes** when the value must change without downtime
  and applying it is cheap (rotating credentials, feature flags, routing tables,
  dynamic tunables). Subscribe to filesystem change notifications and refresh an
  in-process holder when the source changes, so ordinary reads stay in memory.
  Don't re-read the file on every access: that puts I/O on the hot path for a
  value that rarely changes. Polling on a timer is an acceptable fallback when
  watching isn't available. For Kubernetes projected `ConfigMap`/`Secret`
  volumes, watch the mount directory: the kubelet swaps an atomic `..data`
  symlink rather than rewriting the file in place, so a naive watch on the file
  alone can miss updates.
- **Restart to apply** when live reload isn't worth the complexity, typically
  settings baked into stateful resources at construction (changing connection
  pool sizing, for instance, means tearing down and rebuilding the pool, which
  is rarely worth doing live). This is a fine default, but the restart must be
  triggered *by the config change itself*, never left as an out-of-band manual
  step. Prefer putting the values directly in the pod spec as env vars for
  simplicity: changing one changes the pod template, so Kubernetes rolls the
  deployment automatically with no extra tooling. (Secrets are the exception:
  never env vars; see the secrets style guide.) When values must live in a
  `ConfigMap` or file, editing it in place changes nothing in the pod spec, so
  pods keep the old value until something restarts them; tie the change to the
  pod template another way, such as hashing the config into a checksum
  annotation or referencing a versioned `ConfigMap` name. Load at startup and
  document that a change requires a rollout.

The failure mode to avoid is the silent middle: loading once at startup while
assuming rotation "just works" because the mount updates underneath you.

## Keep Refresh Off the Hot Path

When the app does poll or reload config, run it as background work on a timer,
not inline in request handling. See the control-plane / data-plane separation
rule.
