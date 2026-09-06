# Clean code — naming, structure, and the abstraction bar

Applies to every diff, React or not. These are the findings that decide whether the
codebase is pleasant in six months.

---

## CC-1 (P1) — The abstraction bar

> Every abstraction must pay for the indirection it costs.

The default answer to "should I extract this?" is **no**. Extract when:

- there is a **second real caller today** (not an anticipated one), or
- the extraction removes genuine cognitive weight (a gnarly algorithm, a lifecycle
  invariant, a domain rule), or
- it isolates something that changes for a different reason than its surroundings.

Do **not** extract because a function is "long", because a file has three sections,
or because it feels tidy. Wrong abstractions cost more than duplication — duplication
is visible and cheap to fix; a wrong abstraction is load-bearing.

**Rule of three.** Duplicate twice. On the third, extract — by then you can see the
shape. Two similar-looking blocks that will diverge should stay duplicated.

Flag with equal force: **the hook/util/wrapper with one caller** (see `hooks.md` HK-3),
and **the same 30 lines pasted into four files**.

---

## CC-2 (P1) — Naming

Names are the primary documentation. Review them as code.

| Rule                         | Bad                                                | Good                                    |
| ---------------------------- | -------------------------------------------------- | --------------------------------------- |
| Say what it is, not its type | `dataArr`, `userObj`, `handleThing`                | `candidates`, `user`, `handleRowSelect` |
| Booleans read as predicates  | `flag`, `check`, `status` (boolean)                | `isSelected`, `hasAccess`, `canSubmit`  |
| Functions start with a verb  | `submission()`, `userData()`                       | `submitApplication()`, `fetchUser()`    |
| No unexplained abbreviations | `cnd`, `sel`, `tmp`, `res2`                        | `candidate`, `selection`, `response`    |
| Length matches scope         | `candidateSelectionPayload` as a loop index        | `i` in a 3-line loop is fine            |
| Consistent vocabulary        | `fetch` / `get` / `load` / `retrieve` for one idea | pick one and use it everywhere          |
| No negated booleans          | `isNotDisabled`, `hideIfNotVisible`                | `isEnabled`, `isVisible`                |

Repo conventions: components PascalCase, hooks/functions camelCase, constants
UPPER_SNAKE_CASE, directories kebab-case.

**A name that needs a comment to explain it is the wrong name.**

---

## CC-3 (P2) — Magic values

```ts
// ❌
if (candidates.length > 50) { ... }
setTimeout(retry, 3000);
if (status === 3) { ... }

// ✅
const MAX_VISIBLE_CANDIDATES = 50;
const RETRY_DELAY_MS = 3_000;
if (status === ApplicationStatus.Shortlisted) { ... }
```

Every unexplained literal in a condition, a timeout, a slice, or a comparison is a
question the next reader must answer. Numeric status codes and string unions should
be enums or `as const` unions.

---

## CC-4 (P2) — Control flow

**Early return over nesting.** Guard clauses first; the happy path unindented at the
bottom.

```ts
// ❌ arrow code
const submit = (user, form) => {
  if (user) {
    if (user.isActive) {
      if (form.isValid) { ... }
    }
  }
};

// ✅
const submit = (user, form) => {
  if (!user) return;
  if (!user.isActive) return;
  if (!form.isValid) return;
  ...
};
```

Flag 3+ levels of nesting inside a function. Also flag:

- `else` after a `return` — always removable,
- boolean returns wrapped in `if/else` — `return a === b`,
- long `if/else if` chains mapping value → value — use a lookup object,
- a function that does one thing at 5 lines and a second thing at line 40 — split at
  the seam, not by line count.

---

## CC-5 (P1) — Functions

- **One level of abstraction per function.** Don't mix "orchestrate the save" with
  "trim whitespace off field three".
- **Return early, return one type.** A function returning `Row | null | undefined |
false` makes every caller guess.
- **No boolean parameters** — `render(true, false)` is unreadable at the call site.
  Take an options object or split the function.
- **3+ parameters → options object**, especially when several share a type
  (`(id, name, email)` invites a silent argument swap).
- **No output parameters.** Don't mutate an argument to return a result.
- **Pure by default** — a function that both computes and writes is two functions.

---

## CC-6 (P1) — Error handling

- **Never swallow.** An empty `catch {}`, or `catch (e) { }` with only a comment, is
  P1. Log through `@packages/logger` with the `Error` as the second argument, or
  re-throw.
- **No `console.*`** in application code — repo hard rule.
  `log.error('refresh failed', err, { attempt })`.
- **Every `await` has an owner.** An unhandled rejection in a handler crashes silently
  in production.
- **Fail loudly at the boundary, gracefully in the UI.** The user sees a translated
  error state; the logger sees the stack.
- **Don't catch what you can't handle.** A `try/catch` that logs and continues with
  corrupt state is worse than the throw.
- **Error messages are user-facing text** — they need i18n keys too.

---

## CC-7 (P2) — Comments

Comment **why**, never **what**. The code says what.

```ts
// ❌ increments the counter
count += 1;

// ✅ the API rejects page 0, so pagination is 1-based here even though
// the table component is 0-based
const apiPage = tablePage + 1;
```

Flag: commented-out code (delete it — git remembers), a `TODO` with no ticket
reference, a comment that contradicts the code, and a JSDoc block that restates the
signature.

---

## CC-8 (P2) — Dead weight

Every one of these is a P2 on `+` lines, and they accumulate fast:

- unused imports, variables, props, exports, files,
- a parameter nothing reads,
- an `export` with no importer outside its own file (make it module-private),
- a feature flag whose branch is permanently one value,
- debug scaffolding: a leftover `debugger`, a hardcoded test id, a stubbed value.

---

## CC-9 (P2) — File organisation

- One subject per file. A `utils.ts` that has become a junk drawer is a smell.
- Order inside a file: imports → types → constants → helpers → the main export.
- Co-locate: `Component.tsx`, `Component.test.tsx`, `Component.stories.tsx`,
  `Component.styles.ts`, `types.ts`, `constants.ts`.
- Imports auto-sorted by Prettier — never hand-order, never flag ordering as a
  finding (the formatter owns it). Do flag a _wrong source_: `react-intl` instead of
  `@packages/i18n`, a deep path instead of the package entry point.
- Run Prettier **once, last** — mid-task formatting creates diff churn.

---

## CC-10 (P1) — Tests are code under review

Apply CC-1..CC-9 to test files too, plus:

- **Test behaviour, not implementation.** A test asserting `useState` was called with
  a value tests React, not your feature.
- **Query priority**: `getByRole` → `getByLabelText` → `getByText` → `getByTestId`
  **last**. A new `getByTestId` needs a reason.
- **One reason to fail per test.** A test named "works" that asserts nine things
  tells you nothing when it goes red.
- **No `mock.calls[0][1]` traversal** — use `toHaveBeenCalledWith(...)`.
- **Test names state the behaviour**: `'disables submit while the form is invalid'`,
  not `'test submit'`.
- **No conditional logic in tests.** An `if` in a test means it sometimes asserts
  nothing.
- **Every new branch is covered.** A new runtime branch, guard, or state transition
  with no test is P1 and blocking — repo rule.
- Cypress is required for new v8 features; Jest is not a substitute. → `e2e-expert`

---

## Review prompts

1. Does every new abstraction have two callers or a real complexity payoff?
2. Can I understand each name without reading its body?
3. Is there an unexplained literal in a condition?
4. Does any function nest more than three levels?
5. Is any error swallowed, or logged with `console`?
6. Is there commented-out code, an untracked TODO, or an unused export?
7. Do the tests fail for exactly one reason each, and do they test behaviour?
