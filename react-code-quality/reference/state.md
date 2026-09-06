# State — modelling, ownership, and placement

Most "React bugs" are state-modelling bugs. The component is fine; the state shape
made the bug expressible.

---

## ST-1 (P1) — Derive, don't store

> If a value can be computed from props, state, or the URL, **it is not state.**

```tsx
// ❌ four facts, three of them redundant and able to disagree
const [items, setItems] = useState<Item[]>([]);
const [count, setCount] = useState(0);
const [isEmpty, setIsEmpty] = useState(true);
const [total, setTotal] = useState(0);

// ✅ one fact
const [items, setItems] = useState<Item[]>([]);
const count = items.length;
const isEmpty = count === 0;
const total = items.reduce((sum, i) => sum + i.price, 0);
```

Every redundant `useState` is a synchronisation bug waiting for the one code path
that forgets to update it.

**Checklist for each `useState` in the diff:** can I compute it from another state,
a prop, the URL, or the server cache? If yes → P1, delete it.

---

## ST-2 (P1) — Single source of truth

The same fact must live in exactly one place. Common violations:

- Server data copied into local state (`useEffect(() => setRows(data), [data])`) —
  now two caches disagree. Read from the query/store directly.
- A selected item stored as both `selectedId` and `selectedItem`. Store the id;
  look the item up.
- A value in both Redux and component state. Pick one owner.
- A filter in both React state and the URL query string. → ST-6.

```tsx
// ❌
const [selectedId, setSelectedId] = useState<string>();
const [selectedRow, setSelectedRow] = useState<Row>();

// ✅
const [selectedId, setSelectedId] = useState<string>();
const selectedRow = rows.find((r) => r.id === selectedId);
```

---

## ST-3 (P1) — Make impossible states impossible

Independent booleans multiply into states your UI does not handle.

```tsx
// ❌ 8 combinations, 4 of them nonsense (loading AND error AND success?)
const [isLoading, setIsLoading] = useState(false);
const [isError, setIsError] = useState(false);
const [isSuccess, setIsSuccess] = useState(false);

// ✅ 4 states, all real, and TypeScript narrows the payload
type State =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: Result }
  | { status: 'error'; error: Error };
```

Flag any component with 3+ related booleans that describe one process. For anything
with real transition rules, use a machine → `xstate`.

---

## ST-4 (P2) — Colocate state

State belongs at the **lowest common ancestor of its actual consumers**, and no
higher. Lifting "just in case" re-renders the whole subtree on every keystroke and
turns a local concern into a prop-drilling chain.

Review question: _how many of the components between the owner and the consumer
actually read this?_ If the answer is zero for 3+ levels, either push the state down
or restructure with composition (`children`) before reaching for Context.

```tsx
// ✅ composition beats drilling — Layout never sees `user`
<Layout sidebar={<UserPanel user={user} />}>
  <Content />
</Layout>
```

---

## ST-5 (P1) — `useState` vs `useReducer`

Switch to `useReducer` when:

- 3+ state values change together in the same handlers,
- the next state depends on the previous in non-trivial ways,
- the same transition is triggered from several places,
- you are writing `setA(); setB(); setC();` in more than one handler.

A reducer makes transitions named, testable without React, and impossible to
half-apply. If transitions also have guards, entry actions, or async steps →
`xstate`.

---

## ST-6 (P1) — The URL is state

Anything the user could bookmark, share, refresh into, or navigate back to belongs
in the URL — not `useState`:

- current tab, active filters, search query, sort, page number, open detail id.

Local state is for genuinely ephemeral things: dropdown open/closed, hover, an
in-flight uncommitted form draft, focus.

Flag `useState` holding a filter or tab in any routed v8 page. Losing it on refresh
is a UX defect, not a nit.

---

## ST-7 (P1) — State placement (repo rule)

Per `CLAUDE.md`, in order of preference:

| Kind of state                         | Home                                          |
| ------------------------------------- | --------------------------------------------- |
| Component-local, ephemeral            | `useState` / `useReducer`                     |
| Navigation, filters, tabs             | React Router / URL params                     |
| Server data in `modules/*`            | `@packages/store` (`useQuery`, `useMutation`) |
| Server cache elsewhere                | RTK Query                                     |
| Auth, global UI                       | Redux Saga                                    |
| Scoped cross-component, low-frequency | React Context                                 |
| Feature flags                         | GrowthBook                                    |

Two P1 violations to watch for specifically:

- **Parallel data path** — a module already reading a collection from
  `@packages/store` that also opens a direct Apollo query for the same entity.
- **Redux as a dumping ground** — state used by one component tree, placed in a
  global slice. Global state is a cost; it must buy something.

Depth: `state-management` skill.

---

## ST-8 (P1) — Context misuse

Context is a **dependency-injection** tool, not a state manager.

- **Every consumer re-renders on every value change**, regardless of which field it
  reads. High-frequency values (text input, mouse position, timers) in Context is a
  P1 performance defect. Split contexts by update frequency, or keep the fast value
  local.
- **A new object as `value` every render** re-renders all consumers every time.
  Memoise it — this is one of the few places `useMemo` is unambiguously required.
- **Split state and dispatch** into two contexts so dispatch-only consumers do not
  re-render on state changes.
- **A context with one consumer** is a prop with extra steps.

```tsx
// ❌ every consumer re-renders on every parent render
<ThemeContext.Provider value={{ theme, setTheme }}>

// ✅
const value = useMemo(() => ({ theme, setTheme }), [theme]);
<ThemeContext.Provider value={value}>
```

---

## ST-9 (P2) — Mutation and identity

- Never mutate state in place: `items.push(x)` then `setItems(items)` does not
  re-render — same reference. Use `setItems([...items, x])`.
- Inside Redux Toolkit `createSlice`, Immer makes "mutation" correct — do not flag it
  there. Do flag it everywhere else.
- Use the functional updater when the next value depends on the previous:
  `setCount(c => c + 1)`. Two updates in one handler with the direct form lose one.
- Deeply nested state that needs spread-chains to update is a modelling problem;
  normalise it (`createEntityAdapter`) rather than writing the chain.

---

## ST-10 (P2) — State that should not be state at all

- A value that never triggers a render (a timer id, a previous value, an
  imperative instance) → `useRef`.
- A value that never changes → module-level `const`.
- A value only read inside handlers, never rendered → `useRef` or derive on demand.

---

## Review prompts

1. For each `useState`: can this be derived? Can it be in the URL? Is it a ref?
2. Does any fact appear in two places?
3. Do the booleans allow a combination the UI does not render?
4. Is this state as low in the tree as its consumers allow?
5. Is Context carrying a fast-changing value, or an unmemoised object?
6. Does any handler set three states in sequence? (→ reducer)
