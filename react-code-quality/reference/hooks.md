# Hooks — necessity, correctness, and API design

The single most common React defect in this repo is not a broken hook. It is a
**hook that should never have been a hook.**

---

## HK-1 (P1) — The hook necessity test

> A function is a hook **if and only if it calls at least one other hook.**

That is the whole test. React's own guidance: _"Give the `use` prefix to a function
if it uses at least one Hook inside of it. If you don't plan to use Hooks inside it,
now or later, don't make it a Hook."_

Run this on every `use*` function in the diff:

```
Does the function body call useState, useEffect, useMemo, useCallback, useRef,
useContext, useReducer, useSyncExternalStore, useSelector, useDispatch,
useIntl, useQuery, useNavigate, or another use* hook?
│
├─ NO  → It is NOT a hook. P1 finding. Rename and relocate (see HK-2).
│
└─ YES → It is a hook. Continue to HK-3 (does the hook usage earn its keep?).
```

### Why this is a real defect, not a naming quibble

Calling something `use*` when it is a plain function costs you four things:

1. **It infects every caller with the Rules of Hooks.** Callers may no longer call it
   conditionally, in a loop, in an event handler, in a `.map()`, or after an early
   return — even though the function has no state and none of that would break.
2. **`eslint-plugin-react-hooks` enforces that lie**, so callers write awkward
   workarounds around a constraint that does not exist.
3. **It cannot be unit-tested normally.** It now needs `renderHook` and a React
   renderer to test a pure mapping function.
4. **It hides that the logic is pure**, which is the most useful thing a reader could
   have known about it.

### The failing shape

```ts
// ❌ hooks/useCandidateSelectionPayload.ts
export const useCandidateSelectionPayload = (rows: Row[], selectedIds: string[]): SelectionPayload => {
  const selected = rows.filter((r) => selectedIds.includes(r.id));
  return {
    ids: selected.map((r) => r.id),
    count: selected.length,
    allOnPage: selected.length === rows.length,
  };
};
```

No hook is called. This is a pure function wearing a hook costume.

```ts
// ✅ utils/build-candidate-selection-payload.ts
export const buildCandidateSelectionPayload = (rows: Row[], selectedIds: string[]): SelectionPayload => {
  const selected = rows.filter((r) => selectedIds.includes(r.id));
  return {
    ids: selected.map((r) => r.id),
    count: selected.length,
    allOnPage: selected.length === rows.length,
  };
};
```

Now it is callable anywhere, testable with a plain `expect()`, and honest.

### Two false positives — do not flag these

**Sidecar files.** `useThing.types.ts`, `useThing.messages.ts`, `useThing.helpers.ts`
are companions to a hook, not hooks. They are named after the hook they serve. HK-1
applies to the exported `use*` **function**, not to every file starting with `use`.

**A hook that legitimately delegates.** `useX` whose only statement is
`return useSelector(selectX)` calls a hook — it passes HK-1. Judge it under HK-3
instead.

### The near-miss that still fails

A `useMemo` wrapped around a pure computation does **not** make it a hook worth
having. It makes it a pure function with a cache you probably do not need:

```ts
// ❌ still wrong — useMemo added only to justify the `use` prefix
export const useFullName = (user: User): string => useMemo(() => `${user.firstName} ${user.lastName}`, [user]);
```

String concatenation is cheaper than the memo bookkeeping, and `user` is a fresh
object most renders so the memo never hits. Delete the hook; call
`formatFullName(user)` at the point of use. See `performance.md` PF-1.

### Two shapes seen in this repo

**The self-confessed pure function** — the doc comment admits it:

```ts
/** ... this is a pure function of (snapshot, context) ... */
export function useCaptureViewModel(
  snapshot: EnrollmentSnapshot,
  context: EnrollmentContext,
): CaptureViewModel { ... }   // calls no hook
```

If the comment says "pure function", the name must not say "hook".

**The empty hook kept for compatibility** — the effect was correctly moved to module
scope (good, EF-8), but the husk was left behind:

```ts
export const useTelemetrySetup = (): void => {
  // Initialization runs at module scope above; hook is kept for API compatibility.
};
```

An empty hook is a call site that does nothing and a name that lies. Delete it and
its callers — "API compatibility" for an internal module hook is not a reason.

---

## HK-2 (P1) — What to build instead

When HK-1 fails, the replacement is not always "a util". Route it:

| The logic…                                    | Belongs as                         | Where                                                          |
| --------------------------------------------- | ---------------------------------- | -------------------------------------------------------------- |
| Transforms inputs → output, no React          | plain exported function            | `utils.ts` beside the consumer, or `@packages/utils` if shared |
| Is a fixed lookup, map, or list               | module-level `const`               | `constants.ts`                                                 |
| Derives from Redux state                      | selector (`createSelector`)        | the slice's `selectors.ts`                                     |
| Derives from props during render              | inline expression in the component | the component body                                             |
| Renders something                             | a component                        | beside its consumer                                            |
| Is a type-level operation                     | a type or type guard               | `types.ts`                                                     |
| Genuinely needs React state/lifecycle/context | **a hook**                         | per `react-hooks` placement tree                               |

**Default to "inline in the component".** A one-line derivation extracted into a file
is not reuse, it is indirection. Extract on the _second_ real caller, not the first.

---

## HK-3 (P2) — A hook that calls hooks can still be unnecessary

Passing HK-1 is necessary, not sufficient. Flag a hook that calls hooks but earns
nothing:

**Pass-through hooks.** Adds a name and a file, nothing else.

```ts
// ❌ pure indirection
export const useCurrentUser = () => useSelector(selectCurrentUser);
```

Acceptable only if it is the module's deliberate public boundary and is used widely.
One caller → delete it.

**Single-caller hooks with no state.** If it is used once, in one component, and
holds no state that the component could hold itself, it has moved code without
reducing complexity. Inline it.

**"Extract the component's whole body" hooks.** A `useXPage()` that returns fifteen
values consumed by exactly one component has not decoupled anything — it has split
one unit across two files and made the data flow harder to follow. Either the
component is doing too much (split the _component_), or the hook should not exist.

```ts
// ❌ a component turned inside out
const {
  data,
  loading,
  error,
  filters,
  setFilters,
  sort,
  setSort,
  page,
  setPage,
  selected,
  toggle,
  clearAll,
  submit,
  isDirty,
  canSubmit,
} = useCandidateTablePage();
```

**When extraction IS right**, and these are the cases to praise:

- The logic is reused by 2+ components today.
- It wraps an external system (WebSocket, IntersectionObserver, `localStorage`).
- It bundles state + the effect that maintains it into an invariant the caller
  cannot break (`useDebouncedValue`, `usePagination`, `useMediaQuery`).
- It isolates a genuinely tricky lifecycle so the component stops caring about it.

---

## HK-4 (P0) — Rules of Hooks

Hooks must run in the same order on every render. Flag any hook call that is:

- inside `if` / `else` / ternary
- inside `for` / `while` / `.map()` / `.forEach()`
- after a conditional `return` / `throw`
- inside a callback, event handler, `setTimeout`, or a nested function
- inside `try` / `catch`
- in a class component or a plain non-component function

```tsx
// ❌ early return before a hook — order changes between renders
export const Panel = ({ id }: Props): React.ReactElement | null => {
  if (!id) return null;
  const { data } = useQuery(Collections.Candidates, { id }); // conditional
  ...
};

// ✅ hooks first, branch after
export const Panel = ({ id }: Props): React.ReactElement | null => {
  const { data } = useQuery(Collections.Candidates, { id }, { skip: !id });
  if (!id) return null;
  ...
};
```

Note the fix: hooks take a `skip`/`enabled` option precisely so you never have to
call them conditionally.

**Corollary — a component that needs a hook for only some props is two components.**
Split it and branch in the parent, so each child calls its own hooks unconditionally.

---

## HK-5 (P1) — Custom hook API design

When a hook is justified, review its shape:

**Single responsibility.** `useCandidateTable` that fetches, filters, sorts,
paginates, selects and submits is six hooks. Compose them:

```ts
const rows = useCandidates(filters);
const { sort, setSort } = useSort<Candidate>('createdAt');
const selection = useSelection(rows);
```

**Return shape — pick by arity and stick to it.**

| Returns                | Shape     | Example                              |
| ---------------------- | --------- | ------------------------------------ |
| 1 value                | the value | `useIsMobile(): boolean`             |
| 2, order obvious       | tuple     | `useToggle(): [boolean, () => void]` |
| 3+, or optional fields | object    | `{ data, loading, error }`           |

Tuples let the caller rename; objects let the caller take a subset. Never return a
tuple of 4+ — nobody remembers position 3.

**Stable identities.** A hook returning a function or object must not return a new
reference every render unless callers can tolerate it. Wrap handlers in
`useCallback`, wrap returned objects in `useMemo` — _when_ the value crosses a
memo boundary or lands in another hook's dependency array. See `performance.md`.

**Accept the minimum.** Take `userId: string`, not the whole `user` object, if that
is all it reads — the smaller input is stabler and the hook stays testable.

**No hidden side effects in the return path.** A getter that also dispatches, logs,
or navigates is a trap. Return data; return handlers that are obviously handlers.

**Explicit return type on every exported hook.** Repo hard rule; also the fastest way
to notice the hook returns fifteen things.

---

## HK-6 (P1) — Dependency arrays

- **Never lie to the linter.** No `// eslint-disable-next-line react-hooks/exhaustive-deps`
  without a `--` reason, and if the reason is "it loops otherwise", the dependency
  is not the bug — the effect is. Fix the effect.
- **Empty `[]` with referenced values** is a stale closure. The effect captures the
  first render's values forever.
- **Object/array/function literal in deps** changes identity every render, so the
  memo never hits and the effect runs every render. Memoise upstream or depend on a
  primitive field (`user.id`, not `user`).
- **Prefer the functional updater** — `setCount(c => c + 1)` removes `count` from
  the deps entirely.
- **Prefer a ref for "latest value, don't re-run"** — a value the effect reads but
  should not re-trigger on belongs in a ref, not in a disabled lint rule.

---

## HK-7 (P2) — Hook file hygiene

- One hook per file; file named after the hook (`use-debounced-value.ts`, exporting
  `useDebouncedValue`). Directories kebab-case, hook camelCase — repo convention.
- A `hooks/` directory containing non-hooks is a smell — that is HK-1 at folder scale.
  `utils/`, `selectors/`, and `constants.ts` are the right neighbours.
- Placement across `packages/hooks` vs `modules/*/hooks` vs feature-local: see the
  `react-hooks` skill's decision tree. Do not promote speculatively.
- Every exported hook needs a test. A hook with hook calls uses `renderHook`; a
  function that used to be a hook now needs only a plain unit test — which is one of
  the reasons to demote it.

---

## Review prompts

Ask these out loud on any diff containing `use*`:

1. Does this function call a hook? If no → P1, rename and move.
2. If yes, would the caller be simpler with the code inline? If yes → P2, inline it.
3. How many callers does it have today? One and no state → do not extract yet.
4. Can every hook here be called unconditionally? If not → P0, restructure.
5. Does the return shape match the arity rule, and is every identity as stable as
   its consumers need?
6. Does the dependency array tell the truth?
