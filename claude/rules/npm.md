---
paths:
  - "**/package.json"
  - "**/package-lock.json"
  - "**/.npmrc"
---

# npm

## Cooldown

npm's `min-release-age`, set in the project's `.npmrc`, hides every release
inside the window: the window is a bare number of days (`min-release-age=7`),
an exact pin inside it fails with `ETARGET`, a dist-tag falls back to the
newest version outside it, and the bypass is
`min-release-age-exclude[]=<package>` (a name or glob, which exempts that
package but not its dependencies). It also holds back `npm audit fix`: a
patched release younger than the window stays uninstalled, and the command
warns and exits non-zero, so a fresh security fix needs the exemption.
