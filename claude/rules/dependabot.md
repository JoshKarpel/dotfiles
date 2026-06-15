---
paths:
  - ".github/dependabot.yml"
  - ".github/dependabot.yaml"
---

# Dependabot Style Guide

## Schedule

Run version updates weekly, landing PRs on Saturdays so they sit ready for
review over the weekend without interrupting the work week:

```yaml
schedule:
  interval: "weekly"
  day: "saturday"
```

## One PR at a Time

Set `open-pull-requests-limit: 1` so updates arrive serially: one PR to
review and merge before the next opens. This keeps the queue from filling
with parallel update PRs.

## Cooldown

Always set `cooldown`. It delays version updates by a set number of days so a
PR only opens once a release has aged. This is a supply-chain defense: a
compromised or malicious release is usually caught and pulled within days, so
waiting keeps the bad version from ever being proposed for merge.

```yaml
cooldown:
  default-days: 7
  semver-major-days: 30
```

## References

- [Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)
