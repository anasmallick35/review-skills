# Performance — memoisation correctness and render cost

This file covers what a **reviewer** can determine by reading a diff. For the full
58-rule catalogue (bundle analysis, Core Web Vitals, waterfalls), use the
`react-performance` skill.

> **Order of operations:** correctness first, then measure, then optimise. A
> `useMemo` added without a measurement is a cost with a hypothesis attached.

---

## PF-1 (P2) — Memoisation that cannot help

`useMemo` and `useCallback` are not free: they allocate, store deps, and run a
comparison on every render. Flag these:

**Memoising a primitive or a trivial expression.**

```tsx
// ❌ the memo costs more than the work
const total = useMemo(() => a + b, [a, b]);
const label = useMemo(() => `${first} ${last}`, [first, last]);
const isEmpty = useMemo(() => items.length === 0, [items]);
```

**`useCallback` on a handler passed to a plain DOM element or a non-memo child.**

```tsx
// ❌ <button> does not care about identity; the memo does nothing
const onClick = useCallback(() => setOpen(true), []);
return <Button onClick={onClick} />; // Button is not React.memo
```

**Dependencies that change every render**, which makes the memo a pure cost:

```tsx
// ❌ `filters` is a fresh object each render → cache never hits
const rows = useMemo(() => filter(all, filters), [all, filters]);
```

Fix the upstream identity (memoise `filters`, or depend on its primitive fields)
or drop the memo.

**Where memoisation IS justified — do not flag these:**

- A genuinely expensive computation over a large list (sort, group, heavy transform).
- A value passed to a `React.memo` child, a Context `value`, or another hook's
  dependency array — identity is load-bearing there.
- A dependency of `useEffect` that would otherwise re-run the effect every render.
- A ref-like object handed to a third-party imperative API.

---

## PF-2 (P2) — `React.memo` correctness

`React.memo` does nothing if any prop is a new reference each render — which is the
default for objects, arrays, functions, and JSX children.

```tsx
// ❌ memo defeated: three new references per parent render
<MemoRow row={row} style={{ padding: 8 }} onSelect={() => select(row.id)} />
```

Before approving a `React.memo`, check that **every** prop is either primitive or
stably memoised. If not, the memo is dead weight and should be removed or the props
fixed. Also flag `memo()` on a component that renders in under a millisecond and has
one instance — the comparison costs more than the render.

---

## PF-3 (P1) — Identity leaks through props

The commonest silent perf regression: a new object/array/function passed into a
memoised subtree, a Context value, or a dependency array.

```tsx
// ❌ new array literal every render
<Table columns={['name', 'email']} />;
// ✅ module-level constant
const COLUMNS = ['name', 'email'] as const;
```

Default arguments have the same trap: `({ items = [] }) => ...` creates a new `[]`
per render. Hoist the default to a module constant when it crosses a memo boundary.

---

## PF-4 (P1) — Lists

- **Virtualise beyond ~100 rows** (repo rule). Rendering 5,000 DOM nodes blocks
  interaction regardless of how fast each row is.
- **No work inside `.map()` that could hoist out** — building a formatter, a lookup
  map, or a date instance per row.
- **Nested `.find()` inside `.map()` is O(n·m)** — build a `Map` once before the loop.
- **Keys are entity ids** → `components.md` CP-5.
- **Don't sort/filter in the JSX** — derive above the return so it is memoisable and
  readable.

---

## PF-5 (P1) — Waterfalls and loading

- **Sequential `await`s that do not depend on each other** → `Promise.all`.
- **A child that fetches what the parent already has** → pass it down.
- **A query whose key omits a parameter it depends on** returns stale data for the
  new input — a correctness bug, not just a perf one.
- **Route-level `React.lazy`** for anything not on the initial path; heavy libraries
  (charts, editors, PDF) lazy-loaded at the component.
- **Every lazy boundary needs a `Suspense` fallback with real dimensions**, or you
  trade a spinner for layout shift (CLS).
- **Per-section `Suspense`, not one for the whole page** — a single boundary blocks
  everything on the slowest query.

---

## PF-6 (P2) — Render-time work

- No `new Date()`, `Math.random()`, `crypto.randomUUID()`, or a fresh regex in a
  render body — non-deterministic renders, and a new identity every time.
- No synchronous layout reads (`getBoundingClientRect`, `offsetWidth`) in render.
- Debounce/throttle high-frequency handlers (scroll, resize, keystroke search) —
  and clean the timer up.
- Heavy state (a large object) in Context, updated often, re-renders every consumer
  → `state.md` ST-8.

---

## PF-7 (P2) — Bundle

- Import what you use: `import { debounce } from 'lodash-es'`, never
  `import _ from 'lodash'`.
- Watch for a heavy dependency added for one function — a 4-line local helper often
  beats 40 kB.
- Size and dimension images so they do not shift layout.

---

## Review prompts

1. Does each `useMemo`/`useCallback` memoise something expensive, or feed something
   that needs a stable identity? If neither → remove.
2. Do any of its dependencies change every render? Then it never hits.
3. For each `React.memo`: is every prop primitive or stably memoised?
4. Is any list unbounded and unvirtualised?
5. Are there independent `await`s in sequence?
6. Does every query key include everything the query depends on?
