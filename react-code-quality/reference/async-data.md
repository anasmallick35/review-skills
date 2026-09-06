# Async and data — states, races, and failure

A feature is not done when the happy path renders. Review every async surface against
the four states and the three failure modes.

---

## AD-1 (P1) — The four states

Every async surface renders **all four**, deliberately:

| State       | Requirement                                                                           |
| ----------- | ------------------------------------------------------------------------------------- |
| **Loading** | Skeleton or spinner with reserved dimensions (no layout shift)                        |
| **Empty**   | A translated message — never a blank area, never a zero-row table with no explanation |
| **Error**   | A translated message and, where possible, a retry affordance                          |
| **Success** | The data                                                                              |

Flag any component that renders `null` or a bare `<Table rows={[]} />` for empty or
error. A silent blank screen is indistinguishable from a broken app.

**Never infer loading from data length.** With `@packages/store`, `data` is
`undefined` while loading and `[]` when loaded-empty — `!data.length` conflates the
two and flashes the empty state on every load. Use the `loading` flag.

```tsx
// ❌
if (!candidates.length) return <EmptyState />;

// ✅
if (loading) return <TableSkeleton rows={PAGE_SIZE} />;
if (error) return <ErrorState onRetry={refetch} />;
if (candidates.length === 0) return <EmptyState />;
```

---

## AD-2 (P0) — Race conditions

Any fetch keyed on a changing input can resolve out of order. The slow response for
the old input overwrites the fast one for the new input, and the UI shows data that
does not match the query.

Every hand-rolled fetch needs an `ignore` flag or an `AbortController`
→ `effects.md` EF-13.

Also flag:

- **Double submit** — a submit handler with no in-flight guard or disabled button
  creates two records.
- **`setState` after unmount** — an async resolution writing into an unmounted
  component means the cleanup is missing.
- **A mutation whose result races its own refetch** — invalidate and await, don't
  fire and hope.

---

## AD-3 (P1) — Errors are handled, not swallowed

- Every `await` sits inside `try/catch`, or its promise has a `.catch`, or the caller
  demonstrably owns it.
- The catch **logs through `@packages/logger` with the `Error` as the second
  argument** and surfaces a translated message. Never `console`, never empty.
- Distinguish expected failures (validation, 404, permission) from unexpected ones.
  Expected → inline UI message. Unexpected → error state + Sentry.
- `@packages/store` `useMutation` returns a `retryable` `StoreError` and never
  throws — check the returned error is actually read, not ignored.
- **An `ErrorBoundary` wraps every `Suspense` boundary.** Without it, a thrown error
  in a lazy subtree unmounts the whole app.

---

## AD-4 (P1) — Repo data-layer rules

- **`modules/*` reads and writes through `@packages/store`** — the Apollo-like facade
  (`useQuery`, `useQueryOne`, `useLazyQuery`, `useMutation`, `Collections`). Opening a
  parallel Apollo path for an entity already in the store is a P1.
  - Legitimate direct GraphQL: one-off RPCs, file uploads, write-only/audit calls,
    non-replicable third-party data. The PR must say which.
- **Gate with `skip`**, never by calling the hook conditionally → `hooks.md` HK-4.
- **Schema change ⇒ `schema.version` bump + `migrationStrategies` entry + a test**
  under `collections/__tests__/`. Without it RxDB refuses to open the DB and every
  user crashes on load. This is P0 and non-negotiable.
- Note which `useQuery` is in play: `@packages/store`'s or Apollo's. If a file uses
  both, one must be aliased.

---

## AD-5 (P2) — Query hygiene

- **The query key contains every input the query depends on.** A missing filter in
  the key serves the previous filter's data — a correctness bug.
- **Set an explicit `staleTime`** rather than relying on a 0 default that refetches
  on every mount.
- **Don't copy server data into local state** → `state.md` ST-2. Read from the cache.
- **Optimistic updates need a rollback path**, and are never appropriate for
  payments, submissions, or anything the user cannot re-do.
- **Paginate with the cursor the API returns**; don't reconstruct offsets by hand.

---

## AD-6 (P2) — Cancellation and lifecycle

- Cancel in-flight requests on unmount and on input change.
- Cancel debounced work in cleanup — a pending `setTimeout` firing after unmount is
  both a leak and a `setState`-after-unmount.
- Long polls, WebSockets, and intervals are torn down on unmount → `effects.md` EF-14.

---

## Review prompts

1. Are loading, empty, error, and success all rendered, and all translated?
2. Is loading derived from a flag, or wrongly from `data.length`?
3. Can two responses for different inputs land out of order?
4. Can the user submit twice?
5. Is every rejection logged with the `Error` object and surfaced to the user?
6. Does a `Suspense` boundary exist without an `ErrorBoundary` above it?
7. Does the query key include every dependency?
8. Did a store schema change ship without a migration?
