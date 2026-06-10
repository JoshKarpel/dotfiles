---
paths:
  - "**/templates/**/*.yaml"
  - "**/templates/**/*.yml"
  - "**/values*.yaml"
  - "**/values*.yml"
  - "**/Chart.yaml"
  - "**/_helpers.tpl"
---

# Kubernetes Config Management Style Guide

## Adopt Project Conventions First

These are defaults. See the general programming style guide for the full principle.
Match what's already in the project before applying anything below.

## Helm and Crossplane

This guide covers both Helm and Crossplane. They share the same underlying
patterns: a caller-facing interface (values or XRD spec), a rendering layer
(templates or composition resources), and reusable building blocks (named
templates). The same design principles apply to both.

| Concept | Helm | Crossplane |
|---------|------|------------|
| Caller interface | `values.yaml` schema | XRD `spec` schema |
| Caller-supplied config | Values | Composite resource `spec` fields |
| Rendering layer | `templates/` | Composition `resources` |
| Reusable building blocks | `_helpers.tpl` named templates | `function-go-templating` named templates |

## What to Expose as Configuration

Prefer lightweight, opinionated charts and compositions with sensible defaults
baked in. Expose only what callers genuinely need to change, and wait for
proven need before adding a new values key or XRD spec field.

Good candidates:
- Things that vary by environment or deployment (image tags, replica counts,
  resource limits, ingress hostnames)
- Env vars: these are a natural open extension point for container
  configuration, so expose them broadly (see the map pattern below)
- Feature flags for optional components that some deployments will need and
  others won't

Secrets and credentials should not flow through values or XRD spec fields at
all: reference Kubernetes `Secret` objects by name, or use workload identity
(e.g. IAM). At most, a values key or spec field might name which `Secret` to
reference, not hold the secret value itself.

Poor candidates: internal wiring that callers have no reason to change (label
selectors, internal service names, fixed mount paths), or fine-grained knobs
added speculatively before anyone has asked for them. A chart or composition
that exposes everything is harder to use and harder to maintain than one with
a narrow, stable interface.

## Use Helm Built-in Objects

Prefer [Helm's built-in objects](https://helm.sh/docs/chart_template_guide/builtin_objects)
over hardcoded values or custom values keys for things that Helm already knows:

- **Resource names and prefixes**: use `.Release.Name` (or
  `{{ .Release.Name }}-mycomponent`) so that multiple installs of the same
  chart in the same cluster don't collide.
- **Namespace**: use `.Release.Namespace` rather than hardcoding or requiring
  a values key.
- **Image tag**: use `.Chart.AppVersion` as the default image tag. It's set
  in `Chart.yaml`, overridable at package time, and signals which app version
  the chart ships.
- **Chart metadata**: `.Chart.Name`, `.Chart.Version` are useful in labels
  and annotations for traceability.

Release objects (`.Release.Name`, `.Release.Namespace`) are set at deploy
time: by the release name and `--namespace` flag in `helm install`, or by the
application name and destination namespace in ArgoCD. Chart objects
(`.Chart.AppVersion`, `.Chart.Name`, `.Chart.Version`) come from `Chart.yaml`
and are fixed at packaging time. Neither requires a values key. Baking them in
keeps the chart's interface smaller and makes releases self-describing.

## Use Maps, Not Lists, for Mergeable Values

Both Helm and Crossplane merge maps but replace lists. If a Kubernetes object
field is a list and you represent it as a YAML list in `values.yaml` or an
XRD spec array field, any override or higher-level composition that sets that
key replaces the entire list rather than adding to it.

Represent list-typed fields as maps instead, and convert to a list in the
template or composition patch. This way overrides merge with defaults rather
than clobber them.

For a simple list of strings (e.g. `hostAliases` IPs, label selectors):

```yaml
# values.yaml / XRD spec
myArgs:
  --foo: true
  --bar: true
```

```yaml
# template / composition
args:
  {{- range $arg, $enabled := .Values.myArgs }}
  {{- if $enabled }}
  - {{ $arg }}
  {{- end }}
  {{- end }}
```

For a list of objects, key by a stable identifier (usually the `name` field).
Split by shape rather than combining everything into one map: simpler values
stay simple. For `env` specifically, use two maps:

```yaml
# values.yaml / XRD spec
envs:
  MY_VAR: "hello"
  PORT: "8080"

envsFromSecrets:
  SECRET_VAR:
    name: my-secret
    key: secret-key
```

```yaml
# template / composition
env:
  {{- range $name, $value := .Values.envs }}
  - name: {{ $name }}
    value: {{ $value | quote }}
  {{- end }}
  {{- range $name, $ref := .Values.envsFromSecrets }}
  - name: {{ $name }}
    valueFrom:
      secretKeyRef:
        name: {{ $ref.name }}
        key: {{ $ref.key }}
  {{- end }}
```

For other list-of-objects fields (`volumes`, `containers`, etc.), key by a
stable identifier and use `string: object` maps with the same merge-friendly
pattern.

To allow disabling an entry without removing it from the values file or spec,
add an `enabled` field and check it in the template. Volumes are a good
example: a base chart or composition might define several optional volumes; an
override can turn one off without replacing the whole list:

```yaml
# values.yaml / XRD spec
volumes:
  config:
    enabled: true
    configMap:
      name: my-config
  scratch:
    enabled: false
    emptyDir: {}
```

```yaml
# template / composition
volumes:
  {{- range $name, $vol := .Values.volumes }}
  {{- if ne $vol.enabled false }}
  - name: {{ $name }}
    {{- omit $vol "enabled" | toYaml | nindent 4 }}
  {{- end }}
  {{- end }}
```

The `ne $vol.enabled false` check means omitting `enabled` defaults to true,
so entries don't need the field unless they need to be disabled.

Apply this pattern to any list field where you actually expect callers to
additively configure it across override files or layered compositions: `env`,
`envFrom`, `volumes`, `volumeMounts`, `containers`, `initContainers`, and
similar. If a field is unlikely to need additive overrides in practice, a
plain list is fine.

## Named Templates and Reusable Building Blocks

Factor out repeated blocks to reduce duplication and to break large manifests
into readable pieces.

In Helm, use [named templates](https://helm.sh/docs/chart_template_guide/named_templates)
defined in `_helpers.tpl`. In Crossplane, use
[`function-go-templating`](https://github.com/crossplane-contrib/function-go-templating)
to get Helm-like Go template behavior directly in compositions — the same
`range`, `if`, `define`/`include`, and `tpl` patterns all work. This makes the
map-based patterns in this guide directly applicable to Crossplane compositions
without translation.

Common uses:

- **Shared labels and annotations**: define `myapp.labels` and
  `myapp.selectorLabels` once and include them in every resource.
- **Env vars, volumes, volumeMounts**: when the same set appears in multiple
  containers or workloads, extract it to a named template rather than
  duplicating the range logic.
- **Compacting large objects**: a `Deployment` with many containers, volumes,
  and init containers can become unreadable. Named templates (Helm) or
  separate composed resources (Crossplane) let you move sections out of the
  main manifest without losing anything.

```yaml
{{/* _helpers.tpl */}}
{{- define "myapp.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

```yaml
{{/* deployment.yaml */}}
metadata:
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
```

Named templates don't need to map 1:1 to files or resources. Use them freely
to keep individual template files short and scannable.

## Never Use `lookup` (Helm)

Do not use the [`lookup` function](https://helm.sh/docs/chart_template_guide/function_list#lookup).

`lookup` makes live API calls to the Kubernetes cluster during template
rendering. This causes several problems:

- `helm template` (no cluster) returns `nil` for every lookup silently, so
  templates that appear to work locally can produce wrong output or crash in CI.
- Templates become non-deterministic: the same chart renders differently
  depending on what already exists in the cluster.
- Most CI environments lack cluster access at template-generation time, so any
  chart using `lookup` requires special setup or produces broken output.
- It's easy to write a template that works on first install (nothing exists
  yet, lookup returns nil, default kicks in) but silently breaks on upgrade
  (the resource now exists, lookup returns stale data).

Pass values explicitly instead. If a template needs data from cluster state,
require it as a `values.yaml` entry and let the operator supply it.

## References

- [Helm built-in objects](https://helm.sh/docs/chart_template_guide/builtin_objects)
- [Helm template function list](https://helm.sh/docs/chart_template_guide/function_list)
- [Helm named templates](https://helm.sh/docs/chart_template_guide/named_templates)
- [Crossplane docs](https://docs.crossplane.io/)
- [`function-go-templating`](https://github.com/crossplane-contrib/function-go-templating)
