---
name: react-code-quality
description: React/TypeScript code quality and review rubric — hook necessity and correctness, useEffect anti-patterns, state modelling, component structure, props API design, clean-code and naming discipline. Use when reviewing a PR or diff, when auditing code you just wrote, and BEFORE writing new React code so the code lands clean the first time. Triggers on "review my PR", "review this code", "is this hook right", "clean this up", "check my component", and as the rules layer inside the code-review pipeline.
---

# React Code Quality — Review Rubric

The rules layer. `code-review` owns the _pipeline_ (worktree, preflight, sub-agent
dispatch, GitHub posting); this skill owns _what good looks like_.

Use it in two directions:

- **Reviewing** — a PR, a diff, or code you just generated. Walk the workflow below.
- **Writing** — read the relevant reference file _before_ writing the code. A rule
  you apply while writing costs nothing; the same rule applied at review costs a
  round trip.

---

## Prime directive

> Approve when the change leaves the codebase **healthier than it found it** — not
> when the change is perfect.

Two corollaries, and they matter equally:

1. **Never approve a change that degrades code health.** Small regressions compound.
2. **Never block on taste.** "I'd have written it differently" is not a finding. If
   you cannot name a concrete failure, a concrete maintenance cost, or a violated
   repo rule, say nothing.

The most common review failure mode is not missing bugs — it is drowning a correct
PR in preference noise so the real findings get lost.

---

## Severity

| Severity   | Meaning                                                                                                   | Blocks merge                |
| ---------- | --------------------------------------------------------------------------------------------------------- | --------------------------- |
| **P0**     | Wrong behaviour, data loss, security hole, crash, a11y lockout, broken hook rules                         | Yes                         |
| **P1**     | Real defect with narrow blast radius; missing test on a load-bearing path; structural debt that will bite | Fix before merge            |
| **P2**     | Cleanup, naming, minor duplication, style-with-a-reason                                                   | Fix if easy                 |
| **praise** | Something done well                                                                                       | No — but write at least one |

Every finding must survive this gate:

> **State the failure.** Name the input, state, or maintenance scenario that goes
> wrong. If you cannot, downgrade to P2 or drop it.

Write findings as [Conventional Comments](https://conventionalcomments.org/):

```
<label> [decoration]: <subject>

<why it matters, and the fix>
```

Labels: `issue`, `suggestion`, `nitpick`, `question`, `todo`, `praise`, `thought`.
Decorations: `(blocking)`, `(non-blocking)`, `(if-minor)`.

```
issue (blocking): `useCandidateColumns` is not a hook — it calls no hooks.

It takes `columns` and returns a mapped array. Naming it `use*` forces every
caller into the Rules of Hooks (no conditionals, no loops, no callbacks) for
zero benefit. Rename to `buildCandidateColumns` and move it to `utils.ts`.
```

---

## Review workflow

Four passes. Do not skip to pass 3 — most high-value findings live in 1 and 2, and
line-by-line reading without context produces confident nonsense.

### Pass 1 — Intent (before reading any code)

- What is this PR _supposed_ to do? One sentence, from the ticket, not the diff.
- Does the diff do only that? Everything else is scope creep — flag it.
- Is the size reviewable? >400 changed lines of logic → ask whether it splits.

### Pass 2 — Shape (skim the whole diff, no line-by-line)

Ask five questions in this order. Answer them before reading a single line closely.

1. **Does this belong here?** Right module, right layer, right atomic tier. Business
   logic out of components; no cross-`modules/*` imports. → `component-architecture`
2. **Is the abstraction earned?** Every new hook, wrapper, context, provider, generic,
   and config object must justify itself. Default answer is _no_. → `reference/hooks.md`
3. **Is state modelled right?** One source of truth, derived values derived, nothing
   duplicated into `useState`. → `reference/state.md`
4. **Is any of this an effect that shouldn't be?** → `reference/effects.md`
5. **Where are the seams?** What did the author have to touch that they'd rather not
   have? That is where the design is wrong.

### Pass 3 — Line-by-line (`+` lines only)

Read the full file for context; flag only added/changed lines. Walk the rule index
below. For logic rules, trace the changed branch through the surrounding code.

### Pass 4 — Verdict

- Summarise: N blocking, N important, N nits.
- Lead with what is good. At least one `praise`, and mean it.
- State the decision plainly: approve / approve-with-nits / changes-requested.
- If you requested changes, the author must be able to act without asking a question.

---

## The 12 gates

The fast pass. Run these on every React diff before anything else — they catch the
majority of real defects, in descending order of how often they are wrong.

| #   | Gate                       | Fails when                                                | Ref         |
| --- | -------------------------- | --------------------------------------------------------- | ----------- |
| 1   | **Hook necessity**         | A `use*` function calls no hook                           | hooks       |
| 2   | **Effect necessity**       | `useEffect` derives state, reacts to an event, or chains  | effects     |
| 3   | **Derived state**          | A value in `useState` is computable from props/state      | state       |
| 4   | **Rules of hooks**         | Hook behind a condition, loop, callback, or early return  | hooks       |
| 5   | **Component identity**     | Component defined inside another component's body         | components  |
| 6   | **Single source of truth** | The same fact lives in two places                         | state       |
| 7   | **Cleanup**                | Listener, timer, subscription, or fetch without teardown  | effects     |
| 8   | **Props are used**         | Interface field never destructured; callback never called | components  |
| 9   | **Type honesty**           | `any`, unchecked `as`, missing return type on an export   | typescript  |
| 10  | **Async states**           | Loading, empty, and error paths not all handled           | async-data  |
| 11  | **Memo correctness**       | `useMemo`/`useCallback`/`memo` that cannot possibly help  | performance |
| 12  | **Repo hard rules**        | Raw HTML control, raw string, `console.*`, ID fallback    | CLAUDE.md   |

Gates 1–3 are where this repo's React code most often goes wrong. Check them first,
every time.

---

## Rule index

Each reference file is a standalone catalogue: smell → why it breaks → the fix.
Load the ones the diff touches; do not load all eight.

| Reference                                              | Covers                                                                                           | Read when the diff has                    |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------ | ----------------------------------------- |
| [`reference/hooks.md`](reference/hooks.md)             | Hook necessity test, Rules of Hooks, custom-hook API design, hook smells, what to build instead  | any `use*` file or function               |
| [`reference/effects.md`](reference/effects.md)         | 14-pattern `useEffect` anti-pattern catalogue, legitimate uses, cleanup and races                | any `useEffect`                           |
| [`reference/state.md`](reference/state.md)             | Derived state, single source of truth, impossible states, colocation, Context vs Redux vs URL    | `useState`, `useReducer`, Context, slices |
| [`reference/components.md`](reference/components.md)   | Component identity, size, props API, composition over configuration, conditional rendering, keys | any `.tsx`                                |
| [`reference/clean-code.md`](reference/clean-code.md)   | Naming, magic values, nesting, early return, duplication, dead code, comments, file layout       | every diff                                |
| [`reference/typescript.md`](reference/typescript.md)   | `any`/`as`, discriminated unions, prop typing, return types, narrowing                           | every `.ts`/`.tsx` diff                   |
| [`reference/performance.md`](reference/performance.md) | Memoisation correctness, stable identity, list rendering, lazy loading, waterfalls               | memo hooks, lists, routes                 |
| [`reference/async-data.md`](reference/async-data.md)   | Race conditions, abort, loading/empty/error, error boundaries, optimistic updates                | fetch, query, mutation, saga              |

---

## Repo hard rules — non-negotiable

These are enforced by `CLAUDE.md` and are **P0 regardless of anything above**. They
are listed here so the review is one pass, not two.

- **Teserra only** for interactive UI and typography — never raw `<button>`,
  `<input>`, `<select>`, `<textarea>`, `<h1>`–`<h6>`, `<p>`, `<a>`. Never pass
  `className`/`style` to a Teserra atom. → `teserra-components`
- **No raw user-facing text** — JSX children _and_ props (`title`, `alt`,
  `placeholder`, `aria-label`), toasts, errors, empty states. → `i18n-compliance`
- **No `console.*`** — use `@packages/logger`. → `CLAUDE.md`
- **No ID fallbacks** — an ID field resolves to exactly one source; never
  `a.id || b.id`. Absent means `undefined`, not a borrowed ID.
- **No cross-module imports** — `modules/a` must not import `modules/b`.
- **Schema change ⇒ migration** — any `packages/store` schema edit bumps
  `schema.version` and adds a `migrationStrategies` entry.
- **Named exports, functional components, `React.ReactElement | null`** return type.
- **WCAG 2.2 AA** — accessible name on every control, keyboard reachable, visible
  focus. → `accessibility-expert`

---

## Composition with other skills

This skill is the rubric. Delegate depth rather than restating it:

| Concern                                                | Skill                     |
| ------------------------------------------------------ | ------------------------- |
| PR pipeline, worktree, posting to GitHub               | `code-review`             |
| Where a component lives, compound/polymorphic patterns | `component-architecture`  |
| Design-system compliance                               | `teserra-components`      |
| Redux/Context/URL placement, slices, entity adapters   | `state-management`        |
| Hook placement across `packages/` vs `modules/`        | `react-hooks`             |
| Render cost, bundle, waterfalls (58 detailed rules)    | `react-performance`       |
| Test design, RTL query priority                        | `test-driven-development` |
| Cypress coverage requirements for v8 features          | `e2e-expert`              |
| State machines                                         | `xstate`                  |

When this skill and a specialist skill disagree, the specialist wins on its own
subject.

---

## Reviewing your own work

Before you say a task is done, run the 12 gates against your own diff. Two extra
questions that only apply to self-review:

- **Did I add an abstraction because it was needed, or because it felt tidy?**
  Delete every hook, wrapper, and helper that has exactly one caller and no
  hook usage inside it.
- **Did I leave the scaffolding in?** Commented-out code, debug branches, a
  `TODO` with no ticket, an unused prop I added "for later".

Then verify, don't assert. → `verification-before-completion`
