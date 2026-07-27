---
paths:
  - "**/*.tex"
  - "**/*.sty"
  - "**/*.cls"
---

# LaTeX Style Guide

These conventions apply to documents you control. A publisher's class
(`osajnl.cls` and friends) imposes its own rules, and those win.

## Preamble Lives in a Class or Package

All configuration goes in a custom `.cls` or `.sty`. The document body carries
zero `\usepackage` lines: it is content, and the class is the configuration.
This is the parse-at-the-boundary move applied to a document, and it is what
lets the same macro set be shared verbatim across projects.

- Group the preamble by concern, with a comment naming each group
  (`% figures`, `% reference management`, `% source code`).
- Write multi-line package options one per line with a trailing comma, rather
  than one long bracket.
- Set policy once in the class and never repeat it at the call site.
  `\floatplacement{figure}{thb}` in the class means no figure carries `[htbp]`.
- Scope numbering to structure there too: `\numberwithin{equation}{section}`,
  `\counterwithin{figure}{chapter}`.
- Split the body one `\section` per file, gathered per directory and
  `\include`d from the root.

## Semantic Macros

Name the concept, not the glyph. `\efield` rather than `\mathcal{E}` at every
use site, so changing the notation is one edit instead of a global search, and
so the source says what the symbol *means*.

- Compose macros out of macros: `\HamiltonianOp` is `\oper{\Hamiltonian}`, not
  a fresh `\widehat{\mathcal{H}}`.
- Name colours by role, then wrap them: `\definecolor{pump}{HTML}{e41a1c}` and
  `\newcommand{\modeP}{{\color{pump}P}}`. Never a bare hex code in the body.
- Declare custom units with `\DeclareSIUnit` rather than typing `\mathrm{a.u.}`.
- Give a text macro that eats its trailing space a no-space twin
  (`\Schrodinger` and `\SchrodingerNoSpace`) instead of scattering `\ `.

## Math

- Use `align` for essentially everything, with `&` on the relation. Reach for
  `subequations` to group equations that belong together.
- End intermediate steps of a derivation with `\nonumber \\`. Number the
  result, not the scratch work.
- Put the `\label` on the last line of the block, just before `\end{align}`.
- Reference equations with `\eqref`, not `\ref`, so they carry their
  parentheses.
- Use the `physics` package notation consistently: `\qty()` and `\qty[]`
  instead of `\left( \right)`, `\dd{t}` instead of a bare `dt`, and `\ket`,
  `\bra`, `\mel`, `\abs`, `\dv`, `\pdv`.
- Separate factors with thin spaces (`\,`) so products stay readable:
  `-i \, \omega_b \, c_b(t)`.
- A bare `%` on its own line inside a long `align` block separates stages of a
  derivation without affecting output.
- Equations are grammatical parts of sentences. Introduce each one with prose
  and continue the sentence after it. No orphaned display math.

## Figures

Keep the elements blank-line separated, in this order, and let the class handle
placement:

```latex
\begin{figure}
    \centering

    \includegraphics[width = \linewidth]{./figs/mode-energies-vs-pump-power}

    \caption[Mode Energies vs. Launched Pump Power]{
        The energy stored in each resonator mode $U_q$ as a function of
        launched pump power $S_{\modeP}$.
        After threshold, $U_{\modeP}$ is clamped and $U_{\modeS}$ grows like
        the square root of the launched pump power.
    }

    \label{fig:mode-energies-vs-pump-power}
\end{figure}
```

- `width = \linewidth`, a relative `./figs/` path, a kebab-case name, and no
  file extension, so the engine picks the format.
- **The label matches the graphics filename exactly.** Given a figure in the
  PDF you can find its source immediately, and given a source file you can find
  every reference to it.
- The optional short caption is a title-case label for the List of Figures. The
  long caption is a multi-sentence explanation that stands on its own, one
  sentence per line, for a reader who is skimming figures and hasn't read the
  surrounding text.
- `\label` goes last, after the caption.

## Cross-References

- Always a non-breaking tilde before the reference, and capitalize the word:
  `Figure~\ref{...}`, `Section~\ref{...}`, `Equation~\eqref{...}`.
- Prefix labels by type: `chap:`, `sec:`, `eqn:`, `fig:`, `tab:`, `app:`.
- Label in kebab-case, echoing the heading or figure it names.
- Put `\label` on its own line immediately after the heading it belongs to.

## Quantities and Tables

- Every number carrying a unit goes through `siunitx`: `\SI{1064}{\nano\meter}`,
  `\si{\tera\hertz}`, `\SIrange{1}{10}{\tera\hertz}`. Never hand-type a number,
  a space, and a unit. Configure the range phrasing once with `\sisetup`.
- Tables use `booktabs` rules, no vertical rules, with `\arraystretch` loosened
  a little for legibility.

## Source Formatting

- One sentence per line, breaking at commas and clause boundaries within a long
  sentence. A reworded clause then shows up as a one-line diff instead of
  reflowing the paragraph.
- Quote with `` `` `` and `` '' ``, not the ASCII double quote.

## References

- [`physics`](https://ctan.org/pkg/physics) for derivative, bracket, and
  operator notation
- [`siunitx`](https://ctan.org/pkg/siunitx) for quantities and units
- [`booktabs`](https://ctan.org/pkg/booktabs) for tables
