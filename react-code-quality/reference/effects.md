# Effects — the useEffect anti-pattern catalogue

`useEffect` synchronises React with an **external system**. It is not a lifecycle
hook, not a "run this after state changes" hook, and not a place for business logic.

> **The gate:** if removing this effect would only break something _inside_ React,
> it should not be an effect.

Most `useEffect` in a typical PR is unnecessary. Walk every one through the triage
below before reading it closely.

---

## Triage

```
What does the effect do?
│
├─ Sets state computed from props/state ............ EF-1  compute during render
├─ Sets state that is expensive to compute ......... EF-2  useMemo
├─ Resets state when a prop changes ................ EF-3  key prop
├─ Adjusts some state when a prop changes .......... EF-4  derive, or set during render
├─ Runs because the user did something ............. EF-5  event handler
├─ Sends a POST / mutation ......................... EF-6  event handler
├─ Sets state that another effect reacts to ........ EF-7  collapse the chain
├─ Runs once at app start .......................... EF-8  module scope
├─ Notifies the parent after a state change ........ EF-9  call it in the handler
├─ Pushes fetched data up to the parent ............ EF-10 lift the fetch
├─ Subscribes to an external store ................. EF-11 useSyncExternalStore
├─ Seeds state from a prop on mount ................ EF-12 useState initialiser
├─ Fetches data ..................................... EF-13 cleanup, or the store layer
└─ Talks to a real external system ................. LEGITIMATE — check cleanup (EF-14)
```

---

## EF-1 (P1) — Derived state in an effect

```tsx
// ❌ two renders, and a window where fullName is stale
const [fullName, setFullName] = useState('');
useEffect(() => {
  setFullName(`${firstName} ${lastName}`);
}, [firstName, lastName]);

// ✅ one render, never stale
const fullName = `${firstName} ${lastName}`;
```

**Why it is a defect, not a style issue:** the first render paints with the old value,
then the effect fires and paints again. Any consumer reading `fullName` during that
first commit sees a stale value, and the state can desynchronise permanently if a
future edit forgets to update the effect's deps.

Applies equally to filtering, sorting, counting, flag computation, and formatting.

---

## EF-2 (P2) — Expensive derivation cached in an effect

```tsx
// ❌
const [visible, setVisible] = useState<Row[]>([]);
useEffect(() => {
  setVisible(rows.filter(matches(query)));
}, [rows, query]);

// ✅
const visible = useMemo(() => rows.filter(matches(query)), [rows, query]);
```

And measure before reaching for `useMemo` at all — see `performance.md` PF-1.

---

## EF-3 (P1) — Resetting all state when a prop changes

```tsx
// ❌ renders once with the previous candidate's answers
useEffect(() => {
  setAnswers({});
  setStep(0);
  setDirty(false);
}, [candidateId]);

// ✅ React remounts the subtree; every useState re-initialises
<CandidateForm key={candidateId} candidateId={candidateId} />;
```

The `key` prop is the supported way to say "this is a different thing now."

---

## EF-4 (P1) — Adjusting some state when a prop changes

Prefer removing the state entirely. If it must persist, set it during render — React
re-renders the component immediately, without committing the intermediate paint:

```tsx
// ✅ store the previous value and adjust in render
const [prevRows, setPrevRows] = useState(rows);
if (rows !== prevRows) {
  setPrevRows(rows);
  setSelection([]);
}
```

Rarer and more surgical than an effect. Reach for it only when the state genuinely
cannot be derived.

---

## EF-5 (P0) — Event logic in an effect

```tsx
// ❌ also fires on mount, on remount, on any unrelated re-run
useEffect(() => {
  if (submitted) { toast.success(...); navigate('/candidates'); }
}, [submitted]);

// ✅ the cause is the click, so the code lives at the click
const handleSubmit = async (): Promise<void> => {
  await save(values);
  toast.success(...);
  navigate('/candidates');
};
```

P0 because it _duplicates_ user-visible effects — double toasts, double navigation,
double analytics events — under StrictMode, remounts, and Fast Refresh.

**The distinguishing question:** did this happen because the component _appeared_, or
because the user _did something_? Only the first is an effect.

---

## EF-6 (P0) — Mutations fired from an effect

Same defect as EF-5, with data consequences. A POST triggered by a state change fires
twice under StrictMode double-mount and re-fires on any dependency churn. Call the
mutation directly in the handler.

---

## EF-7 (P1) — Effect chains

```tsx
// ❌ four renders, and an impossible-to-follow causal chain
useEffect(() => {
  setB(f(a));
}, [a]);
useEffect(() => {
  setC(g(b));
}, [b]);
useEffect(() => {
  setD(h(c));
}, [c]);
```

Derive what can be derived (`const b = f(a)`), and compute the rest in one pass inside
the handler that started it. Each link is a wasted render and a frame where the state
is internally inconsistent.

---

## EF-8 (P2) — App initialisation in an effect

`useEffect(() => { init(); }, [])` runs twice in development StrictMode. If `init` is
not idempotent, use module scope or a module-level guard:

```ts
let started = false;
export const startTelemetry = (): void => {
  if (started) return;
  started = true;
  ...
};
```

Repo note: `configureLogging()` and Sentry setup are wired once at the app root and
never per feature. Flag any per-feature setup call.

---

## EF-9 / EF-10 (P1) — Talking to the parent through an effect

**EF-9 — notifying:** `useEffect(() => onChange(value), [value])` fires on mount and
on every unrelated re-render. Call `onChange(next)` in the same handler that calls
`setValue(next)`.

**EF-10 — pushing data up:** a child that fetches and then `onLoaded(data)` inverts the
data flow. Fetch in the parent, pass down as props. Data flows down.

---

## EF-11 (P2) — Manual external-store subscription

Effect + `useState` + `addEventListener` to mirror an external value is
`useSyncExternalStore`'s job — and only it is tear-free under concurrent rendering:

```ts
const isOnline = useSyncExternalStore(
  subscribe,
  () => navigator.onLine,
  () => true,
);
```

---

## EF-12 (P1) — Seeding state from a prop on mount

```tsx
// ❌ clobbers user edits whenever the effect re-runs
useEffect(() => {
  setDraft(initialDraft);
}, [initialDraft]);

// ✅
const [draft, setDraft] = useState(initialDraft);
```

If the prop must be able to reset the state later, that is EF-3 — use `key`.

---

## EF-13 (P0) — Fetch without race protection

```tsx
// ❌ the slower response wins, regardless of which query is current
useEffect(() => {
  fetchResults(query).then(setResults);
}, [query]);

// ✅
useEffect(() => {
  let ignore = false;
  fetchResults(query).then((r) => {
    if (!ignore) setResults(r);
  });
  return () => {
    ignore = true;
  };
}, [query]);
```

P0 because it renders data that does not match the input — a wrong-data bug, not a
performance one.

**In this repo, prefer not writing this at all.** `modules/*` reads through
`@packages/store` (`useQuery`/`useQueryOne`), which owns caching, cancellation, and
the `{ data, loading, error }` contract. A hand-rolled fetch effect inside `modules/*`
where a collection already exists is a P1 parallel-data-path violation on its own.

---

## EF-14 (P0) — Missing cleanup

Every one of these must return a teardown:

| Set up                                                         | Tear down                                     |
| -------------------------------------------------------------- | --------------------------------------------- |
| `addEventListener`                                             | `removeEventListener`                         |
| `setInterval` / `setTimeout`                                   | `clearInterval` / `clearTimeout`              |
| `IntersectionObserver` / `ResizeObserver` / `MutationObserver` | `.disconnect()`                               |
| WebSocket / EventSource                                        | `.close()`                                    |
| Redux/RxDB/third-party subscription                            | the returned unsubscribe                      |
| `requestAnimationFrame`                                        | `cancelAnimationFrame`                        |
| in-flight fetch                                                | `AbortController.abort()` or an `ignore` flag |

Also check the cleanup is _correct_: `removeEventListener` with a different function
identity than `addEventListener` removes nothing.

---

## Legitimate effects — do not flag these

- Subscribing to a real external system with cleanup (WebSocket, browser API,
  third-party widget, media device).
- Imperative DOM work React cannot express: focus management on mount, scroll
  position restore, canvas/chart instance lifecycle.
- Animations and timers scoped to the component's lifetime.
- Analytics for _component display_ — a "screen viewed" event. (A "button clicked"
  event is EF-5.)
- Synchronising a controlled third-party instance with props it does not accept
  reactively.

When you see one of these, check cleanup and deps and move on. Consider a `praise`
comment — correct effect usage is rarer than it should be.

---

## Review prompts

1. Would deleting this effect break anything _outside_ React? If no, it should not
   exist.
2. Did this happen because the component appeared, or because the user acted?
3. Does it call `setState` with a value computable during render?
4. Does it set state another effect depends on?
5. Does it set up anything that is not torn down?
6. Does it fetch without an `ignore` flag or `AbortController`?
7. Is it safe to run twice back-to-back? (StrictMode will.)
