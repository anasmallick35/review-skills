# React PR Checklist

Copy into a PR review or run mentally before pushing. Every unchecked box is either
a fix or a stated reason.

## Intent

- [ ] The PR does what the ticket says, and only that
- [ ] Scope creep is called out, not silently absorbed
- [ ] Size is reviewable (<400 lines of logic) or split is discussed

## Hooks — `reference/hooks.md`

- [ ] Every `use*` function calls at least one hook (HK-1)
- [ ] No hook exists with one caller and no state it needs (HK-3)
- [ ] Every hook is called unconditionally — no conditions, loops, callbacks, or
      calls after an early return (HK-4)
- [ ] Return shape matches arity: 1 value / tuple / object (HK-5)
- [ ] Dependency arrays are honest; no unexplained `exhaustive-deps` disable (HK-6)
- [ ] Non-hooks live in `utils.ts` / `constants.ts` / `selectors.ts`, not `hooks/`

## Effects — `reference/effects.md`

- [ ] No effect that only derives state (EF-1) or caches a computation (EF-2)
- [ ] No effect that reacts to a user action, toast, navigation, or POST (EF-5/6)
- [ ] No effect chains — one effect's state feeding the next (EF-7)
- [ ] No effect notifying the parent or pushing data upward (EF-9/10)
- [ ] Prop-change resets use `key`, not an effect (EF-3)
- [ ] Every fetch has an `ignore` flag or `AbortController` (EF-13)
- [ ] Every listener, timer, observer, and subscription is torn down (EF-14)
- [ ] Every effect is safe to run twice (StrictMode)

## State — `reference/state.md`

- [ ] Nothing in `useState` that can be derived (ST-1)
- [ ] No fact stored in two places (ST-2)
- [ ] No booleans that combine into impossible states (ST-3)
- [ ] State sits at the lowest common ancestor of its consumers (ST-4)
- [ ] Bookmarkable state (tab, filter, sort, page, search) is in the URL (ST-6)
- [ ] Redux/Context/store placement follows the repo table (ST-7)
- [ ] Context values are memoised; no fast-changing value in Context (ST-8)
- [ ] No in-place mutation outside `createSlice` (ST-9)

## Components — `reference/components.md`

- [ ] No component, `styled()`, `memo()`, or `lazy()` created inside a render body (CP-1)
- [ ] Multi-component files are fine — no findings raised on that alone (CP-2)
- [ ] No component extracted for a single-use 10-line block (CP-2)
- [ ] Every declared prop is destructured and used; every callback prop is invoked (CP-4)
- [ ] Boolean props haven't multiplied — composition or a union instead (CP-4)
- [ ] Keys are stable entity ids; no index, no random (CP-5)
- [ ] `&&` guards coerce to boolean — no `{items.length && ...}` (CP-6)
- [ ] Under ~200 lines, one responsibility

## Types — `reference/typescript.md`

- [ ] No `any`, no unchecked `as`, no `as unknown as`, no bare `!` (TS-1)
- [ ] `@ts-expect-error` over `@ts-ignore`, always with a `--` reason
- [ ] Explicit return type on every exported function, hook, and component (TS-2)
- [ ] Components return `React.ReactElement | null`
- [ ] Mutually exclusive optionals modelled as a discriminated union (TS-3)
- [ ] `??` not `||` for defaults; no `||` fallback chain on an ID (TS-5)

## Async — `reference/async-data.md`

- [ ] Loading, empty, error, and success are all rendered and translated (AD-1)
- [ ] Loading comes from a flag, never from `data.length` (AD-1)
- [ ] Out-of-order responses cannot land (AD-2)
- [ ] Double submit is prevented (AD-2)
- [ ] Every rejection is logged with the `Error` object and surfaced (AD-3)
- [ ] `ErrorBoundary` above every `Suspense` (AD-3)
- [ ] `modules/*` reads through `@packages/store`, not a parallel Apollo path (AD-4)
- [ ] Store schema change ships a version bump + migration + test (AD-4)
- [ ] Query keys include every dependency (AD-5)

## Performance — `reference/performance.md`

- [ ] Every `useMemo`/`useCallback` is expensive or identity-critical (PF-1)
- [ ] Every `React.memo`'s props are primitive or stably memoised (PF-2)
- [ ] No fresh object/array/function literal crossing a memo boundary (PF-3)
- [ ] Lists over ~100 rows are virtualised (PF-4)
- [ ] Independent awaits run with `Promise.all` (PF-5)
- [ ] Non-initial routes are `React.lazy` with a sized fallback (PF-5)

## Clean code — `reference/clean-code.md`

- [ ] Every new abstraction has a second caller or real complexity payoff (CC-1)
- [ ] Names say what the thing is; booleans read as predicates (CC-2)
- [ ] No magic literals in conditions, timeouts, or comparisons (CC-3)
- [ ] Guard clauses over nesting; max 3 levels (CC-4)
- [ ] No swallowed errors; no `console.*` (CC-6)
- [ ] No commented-out code, no untracked TODO, no unused export (CC-7/8)

## Repo hard rules — `CLAUDE.md`

- [ ] Teserra atoms for every control and every piece of typography
- [ ] No `className`/`style` passed to a Teserra atom
- [ ] No raw user-facing string — including `title`/`alt`/`placeholder`/`aria-label`
- [ ] Every i18n id exists in every locale file
- [ ] `@packages/logger`, never `console.*`
- [ ] No cross-`modules/*` imports
- [ ] No ID fallback chains
- [ ] Named exports, functional components
- [ ] `data-testid` only as a last resort

## Accessibility

- [ ] Every control has an accessible name
- [ ] No `onClick` on a `div`/`span`
- [ ] Keyboard: tab order, Enter/Space, Escape, focus trap and restore
- [ ] Focus is visible; contrast 4.5:1 text / 3:1 UI

## Tests

- [ ] Every new branch, guard, and state transition is covered
- [ ] `getByRole` → `getByLabelText` → `getByText` → `getByTestId` last
- [ ] Tests assert behaviour, fail for one reason, contain no conditionals
- [ ] Cypress spec exists for a new v8 feature, green locally and in CI

## Verdict

- [ ] Blocking / important / nit counts stated
- [ ] At least one `praise`
- [ ] Every finding names a concrete failure or cost
- [ ] The author can act on every comment without asking a question
