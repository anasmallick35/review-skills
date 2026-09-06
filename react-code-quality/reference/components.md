# Components — identity, structure, and props API

---

## CP-1 (P0) — Never define a component inside another component's body

This is the highest-severity structural defect in React, and it looks harmless.

```tsx
// ❌ `Row` is a NEW component type on every render of `List`
export const List = ({ items }: Props): React.ReactElement => {
  const Row = ({ item }: RowProps) => <li>{item.name}</li>;
  return (
    <ul>
      {items.map((i) => (
        <Row key={i.id} item={i} />
      ))}
    </ul>
  );
};
```

React compares element types by identity. A new function each render means a new
type, so React **unmounts and remounts the entire subtree every render**:

- all state inside `Row` resets,
- focus is lost mid-typing,
- inputs clear, scroll position jumps,
- CSS transitions and animations restart,
- every effect inside re-runs teardown + setup.

The bug reports read as "the search box loses focus after one character" — nobody
looks at the component definition.

```tsx
// ✅ module scope: stable identity
const Row = ({ item }: RowProps): React.ReactElement => <li>{item.name}</li>;

export const List = ({ items }: Props): React.ReactElement => (
  <ul>
    {items.map((i) => (
      <Row key={i.id} item={i} />
    ))}
  </ul>
);
```

**Same rule for `styled(...)` calls, `memo(...)`, `lazy(...)`, and factory helpers**
invoked inside a render body — all produce a fresh type per render.

---

## CP-2 (encouraged) — Several components in one file is good

CP-1 is about _where a component is defined_, not _which file it lives in_. Multiple
components at module scope in the same file is co-location, and it is the preferred
shape for small helpers used by exactly one parent:

```tsx
// ✅ CandidateTable.tsx — all at module scope, one file
const EmptyState = (): React.ReactElement => (
  <Paragraph><FormattedMessage id="recruit.table.empty" /></Paragraph>
);

const StatusBadge = ({ status }: BadgeProps): React.ReactElement => (
  <Badge tone={TONE_BY_STATUS[status]}>{status}</Badge>
);

export const CandidateTable = ({ rows }: Props): React.ReactElement => { ... };
```

Do **not** ask for a new file per component. Split a file when it crosses ~200 lines,
when a helper gains a second consumer, or when the file stops having one subject —
not because it contains three function declarations.

Equally: **do not create a component for a single-use 10-line JSX block.** One 40-line
readable JSX return beats five 8-line components you must jump between. Extract when
there is reuse or real cognitive weight — the same bar as HK-3 for hooks.

---

## CP-3 (P1) — Component size and responsibility

Repo rule: keep components under 200 lines. But the line count is the symptom;
review the cause:

- **Multiple responsibilities** — fetching + layout + form + table in one component.
  Split by responsibility, not by line count.
- **Deep JSX nesting (4+ levels)** with logic at each level → extract the inner
  layers.
- **Long conditional-render chains** → extract per-branch components, or a lookup map.
- **The component is a page** — pages compose; they should be mostly composition,
  with logic pushed into children, hooks, and the data layer.

A 250-line component that is one obvious form is fine. A 120-line component doing
three unrelated things is not.

---

## CP-4 (P1) — Props API design

**Props must be used.** An interface field never destructured, a callback prop never
invoked, a config prop ignored while a hardcoded constant remains — all P1. This is
the single most common "the feature silently does nothing" defect.

**Take the minimum.** `candidateId: string` beats `candidate: Candidate` when only
the id is read: smaller surface, stabler identity, trivial to test.

**Prefer composition over configuration.** When boolean props multiply, the component
is doing too many jobs:

```tsx
// ❌ 6 booleans = 64 states, of which ~5 are real
<Card hasHeader hasFooter isCompact showAvatar showActions isSelectable />

// ✅ the caller composes what it needs
<Card>
  <Card.Header avatar={<Avatar user={user} />} />
  <Card.Body>{children}</Card.Body>
  <Card.Footer><Button>Save</Button></Card.Footer>
</Card>
```

**Use a union, not parallel booleans.** `variant: 'primary' | 'danger'` beats
`isPrimary` + `isDanger`, which allows both at once.

**Naming.** Handlers `onX` (prop) / `handleX` (implementation). Booleans read as
predicates: `isOpen`, `hasError`, `canSubmit` — never `open` or `flag`.

**No prop drilling past 2–3 inert levels.** Restructure with `children`/slots first;
Context only when composition genuinely cannot express it → `state.md` ST-4/ST-8.

**Never spread unknown props** — `<div {...props} />` hides the real API and leaks
`key`/`ref`/DOM warnings. Spread only a typed rest of a known interface.

---

## CP-5 (P1) — Keys

- **Never use the array index** as `key` for a list that can reorder, filter, insert,
  or delete. React reuses the wrong DOM node: state and input values attach to the
  wrong row. Index keys are only safe for a static, append-only, never-reordered list.
- **Never use `Math.random()` or a fresh uuid** — a new key each render remounts the
  row every time. This is CP-1's failure mode by another route.
- Keys must be **stable and unique among siblings** — the entity id.
- Repo rule: no ID fallbacks. `key={row.id}`, never `key={row.id || row.email}`.

---

## CP-6 (P2) — Conditional rendering

```tsx
// ❌ renders a literal "0" when items is empty
{
  items.length && <List items={items} />;
}

// ✅
{
  items.length > 0 && <List items={items} />;
}
```

`&&` with a number renders `0`; with an empty string renders nothing but is still a
trap. Coerce to boolean explicitly.

- Nested ternaries in JSX are unreadable past one level — extract a variable or an
  early return.
- Always handle the empty and error branches; a component that renders `null` for
  "no data" without an empty state is a UX gap → `async-data.md`.

---

## CP-7 (P1) — Placement, layering, and the repo's hard rules

- **Atomic tier and reuse scope** — narrowest scope that fits; promote only when a
  real second consumer appears. → `component-architecture`
- **`teserra/*` vs `@packages/components`** — the split is _domain knowledge_, not
  complexity. → `CLAUDE.md`
- **No cross-`modules/*` imports.** Promote to `packages/`.
- **Teserra only** for controls and typography; **never** `className`/`style` on an
  atom. → `teserra-components`
- **No raw user-facing strings**, including `title`/`alt`/`placeholder`/`aria-label`.
  → `i18n-compliance`
- **Named export, functional, `React.ReactElement | null` return type.**
- Co-locate `Component.{tsx,test.tsx,stories.tsx,styles.ts}`.

---

## CP-8 (P0) — Accessibility floor

Not a separate review pass — part of every component finding:

- Every control has an accessible name (visible label, `aria-label`, or
  `aria-labelledby`).
- Every interactive thing is a real control: no `onClick` on a `div`/`span`. A
  clickable non-button is unreachable by keyboard and invisible to screen readers.
- Keyboard: tab order sane, Enter/Space activate, Escape closes overlays, focus is
  trapped in modals and restored on close.
- Focus is visible. Never `outline: none` without a replacement.
- `aria-*` only where semantics fall short; wrong ARIA is worse than none.

Depth: `accessibility-expert`, `web-interface-audit`.

---

## Review prompts

1. Is any component (or `styled`/`memo`/`lazy` call) defined inside a render body?
2. Is every declared prop destructured and actually used?
3. Do the boolean props multiply into states nobody renders?
4. Are keys stable entity ids?
5. Does every `&&` guard coerce to boolean?
6. Does this component have one subject, or three?
7. Would a reader understand the JSX without jumping to another file? (If the
   extraction hurt readability, inline it back.)
