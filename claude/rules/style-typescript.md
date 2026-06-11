---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/tsconfig*.json"
---

# TypeScript Style Guide

## Compiler Settings

Always use `strict: true`. Enable these additional flags:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "isolatedModules": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

Avoid `any`. Use `unknown` when a type is genuinely unknown and narrow it before use. Never use `as unknown as T` to silence a legitimate type error.

## Types

- **`interface` for object shapes; `type` for unions, intersections, and aliases.**
- **Discriminated unions** over optional fields: `{ kind: "a"; a: string } | { kind: "b"; b: number }` is exhaustively checkable; `{ kind: "a" | "b"; a?: string; b?: number }` is not.
- **`as const`** for literal tuples and objects that shouldn't widen to their base types.
- **`satisfies`** (TS 4.9+) to validate an expression against a type without widening it.
- Avoid type assertions (`as T`) except at system boundaries where you genuinely know more than the compiler.

## Imports

Use `import type { Foo }` for type-only imports — required by `isolatedModules` and lets bundlers tree-shake more aggressively.

Use `simple-import-sort` (via ESLint) to enforce import ordering automatically.

## React

- **Functional components only.** No class components.
- `PascalCase` for component names and the files that export them.
- Type props as an `interface Props` at the top of the file, or inline if small.
- Keep `react-hooks/exhaustive-deps` set to `error`; fill dependency arrays correctly rather than suppressing.
- `useCallback` / `useMemo` for values passed to child components or used as `useEffect` dependencies, not as a general optimization.

## Formatting

Prettier config:

```json
{
  "printWidth": 100,
  "semi": false,
  "trailingComma": "all",
  "endOfLine": "lf"
}
```

Alternatively, `@stylistic/eslint-plugin` handles the same rules entirely within ESLint, removing the need for a separate Prettier process.

## Linting

ESLint with:
- `typescript-eslint` (recommended or strict)
- `eslint-plugin-react` + `eslint-plugin-react-hooks`
- `eslint-plugin-simple-import-sort`
- `unused-imports` (or `@typescript-eslint/no-unused-vars` + `no-unused-vars`)
- `eslint-config-prettier` to disable formatting rules when using Prettier

## Toolchain

- **`tsc --noEmit`** for type checking
- **Prettier** or **`@stylistic/eslint-plugin`** for formatting
- **ESLint** for linting
- **Vite** + **Vitest** for bundling and testing
- **Yarn** for package management

## References

- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [React docs](https://react.dev/)
