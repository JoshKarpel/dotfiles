---
paths:
  - "**/test_*.py"
  - "**/*_test.py"
  - "**/conftest.py"
  - "**/tests/**/*.py"
---

# Python Tests

- **When patching is unavoidable, patch where the name is looked up,
  not where it's defined.**
  A shim module that re-imports a third-party function binds its own name to it
  at import time; patching the shim leaves call sites that import directly
  from the third-party module untouched.
  Patch the module that actually resolves the name at runtime.
