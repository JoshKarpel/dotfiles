# Configuration

## Parse at the Boundary

Read and validate configuration once, where it enters the process,
into a single typed object, rather than scattering raw `os.environ` lookups
or re-parsing the same file throughout the code.
Missing or malformed settings then fail loudly at startup rather than
at first use, and the rest of the code gets already-valid values.
Reach for a settings library that parses into a validated type rather
than reading raw values yourself (in Python, for example, `pydantic-settings`).

## Dynamic Reload Is the App's Responsibility

A platform that delivers updated config (a Kubernetes `ConfigMap`/`Secret`
directory mount, a config service, a watched file) only updates the *source*.
A running process keeps using whatever it loaded until it reads again,
so mounting config to update in place does nothing on its own.
Decide deliberately, per setting, how a change takes effect:

- **Watch the source for changes** when the value must change without downtime
  and applying it is cheap (rotating credentials, feature flags, routing tables,
  dynamic tunables).
  Subscribe to filesystem change notifications and refresh an in-process holder,
  so ordinary reads stay in memory.
  Don't re-read the file on every access,
  which puts I/O on the hot path for a value that rarely changes.
  Polling on a timer is an acceptable fallback when watching isn't available.
- **Restart to apply** when live reload isn't worth the complexity,
  typically for settings baked into stateful resources
  at construction (resizing a connection pool means tearing it down
  and rebuilding it, which is rarely worth doing live).
  This is a fine default, but the restart must be triggered
  *by the config change itself*, never left as an out-of-band manual step:
  an edit that doesn't change what the deployment runs reaches no process
  until something unrelated restarts it.
  Load at startup and document that a change requires a rollout.

The failure mode to avoid is the silent middle: loading once at startup
while assuming rotation "just works" because the mount updates underneath you.
