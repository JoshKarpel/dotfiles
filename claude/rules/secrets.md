# Secrets

## Source Hierarchy

Prefer sources higher on this list. They all propagate a rotated value without
a restart; what each step down trades away is the *absence* of long-lived
secret material to store, leak, and manage, along with some blast-radius control
and auditability. Only drop down when the step above genuinely isn't available.

1. **Workload identity (IAM).** Best: the workload authenticates *as itself*
   and the cloud issues short-lived, auto-rotated credentials. There is no
   long-lived secret to store, leak, or rotate. Each cloud provider has its own
   workload-identity mechanism for mapping a pod's service account to a cloud
   identity; use the one for your platform. Workload identity federation (WIF)
   extends this across clouds and to external OIDC providers: a workload in one
   cloud (or a CI runner, or on-prem) exchanges its own identity token for
   short-lived credentials in another, so cross-cloud access still needs no
   stored key. This covers most cloud-service access (databases, object storage,
   queues, other APIs that support IAM auth); reach for a stored secret only for
   third parties that can't do identity-based auth.

2. **External secrets manager, projected short-lived.** When a static secret
   is unavoidable, keep it in a dedicated manager (AWS Secrets Manager, GCP
   Secret Manager, Vault) and pull it into the cluster at runtime with the
   [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
   or [External Secrets Operator](https://external-secrets.io/). The secret
   lives in one auditable, rotatable place; the cluster gets a synced or
   freshly-fetched copy rather than the source of truth.

3. **Mounted Kubernetes `Secret` as a file.** Project the `Secret` as a volume
   and read it from disk at the point of use. The kubelet propagates updates to
   mounted files, so a rotated `Secret` reaches a running pod without a restart,
   and file contents don't leak the way the environment does.

**Never mount secrets as env vars.** Env vars are fixed at process start, so a
rotated `Secret` never reaches a running pod without a restart, defeating
rotation entirely. They also leak readily: inherited by every child process,
surfaced in crash dumps and error trackers, exposed in `/proc/<pid>/environ`,
and easy to log by accident. Mount as a file and read it off disk instead.

Likewise never hardcode secrets in image layers, source code, command-line args
(visible in `ps` and process listings), or plain `ConfigMap`s. A value baked
into an image is permanent: it ships everywhere the image does and can't be
rotated without a rebuild.

## Handling Secrets Once Loaded

- **Wrap them in a redacting type.** Don't carry raw secret strings around.
  In Python, use Pydantic's `SecretStr` so the value stays out of `repr()`,
  logs, and tracebacks; see the Python style guide.
- **Never log secrets**, and be wary of logging whole objects, request bodies,
  or config dumps that might contain them.
- **Don't pin the value at startup.** A secret loaded once and held for the
  process lifetime goes stale when it rotates. Pick up the rotated value the way
  you would any reloadable config: watch the mounted file and refresh an
  in-process holder, not re-read on every access (see the configuration style
  guide). Re-fetching on an auth failure is a reasonable extra safety net for
  credentials. Don't copy the secret into wider-scoped variables or telemetry.

## Scope and Lifecycle

- **Least privilege.** Scope each credential to exactly what one workload
  needs. Per-workload identities and per-workload secrets keep a leak from
  becoming a cluster-wide compromise.
- **Plan for rotation.** All three sources above propagate a rotated value into
  a running pod without a restart (that's why env vars are out): IAM credentials
  refresh in the client SDK, and projected/mounted files are updated in place.
  The app must make sure it actually picks up the new value (see not pinning the
  value above) rather than pinning whatever it saw at startup.
- **Keep secrets out of config interfaces.** Helm values, XRD specs, and
  similar should reference a `Secret` by name, never carry the value itself.
  See the Helm and Crossplane style guide.

## References

- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [External Secrets Operator](https://external-secrets.io/)
