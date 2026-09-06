# TypeScript — type honesty

A type that lies is worse than no type: it turns a compile error into a runtime one
and tells the next reader a falsehood with the compiler's authority.

---

## TS-1 (P0) — `any` and unchecked `as`

Both are P0 when they bypass validation at a boundary (API response, URL param,
`localStorage`, form input, third-party payload).

```ts
// ❌ asserts a shape nobody verified
const user = JSON.parse(raw) as User;

// ✅ narrow with a guard
const parsed: unknown = JSON.parse(raw);
if (!isUser(parsed)) throw new InvalidUserError();
const user = parsed;
```

- `unknown` is the honest type for unvalidated input. It forces the narrowing.
- `as` is acceptable for a genuine widening the compiler cannot see (`as const`,
  narrowing a union you just checked). It is never acceptable to silence an error.
- `any` in a `.d.ts` shim for an untyped dependency: acceptable, with a `--` reason.
- `@ts-ignore` / `@ts-expect-error` without a `-- reason` suffix: P1.
  `@ts-expect-error` is strictly better than `@ts-ignore` — it fails when the error
  goes away.
- **`as unknown as T` is always a finding.** It is a double lie.

---

## TS-2 (P1) — Explicit return types on exports

Repo rule, and it earns its keep: it stops an internal refactor from silently
widening a public signature, and it surfaces "this hook returns fifteen things".

```ts
// ✅
export const buildPayload = (rows: Row[]): SelectionPayload => { ... };
export const useSelection = (rows: Row[]): UseSelectionResult => { ... };
export const Panel = ({ id }: Props): React.ReactElement | null => { ... };
```

Components return `React.ReactElement | null`, never `JSX.Element`.

---

## TS-3 (P1) — Model with unions, not optional soup

```ts
// ❌ 2^4 combinations; most are impossible, all are representable
interface Result {
  data?: Candidate[];
  error?: Error;
  isLoading?: boolean;
  isEmpty?: boolean;
}

// ✅ discriminated union: the compiler narrows the payload
type Result = { status: 'loading' } | { status: 'error'; error: Error } | { status: 'success'; data: Candidate[] };
```

Rule: **if two optional fields can never both be present, they belong in a union.**

Similarly, prefer a union of literals over `string`:
`type Tone = 'neutral' | 'success' | 'danger'` — not `tone: string`.

---

## TS-4 (P2) — Interface vs type, and prop shapes

- `interface` for object/prop shapes; `type` for unions, intersections, mapped and
  conditional types. Repo convention.
- Props interface named `Props` locally, or `<Component>Props` when exported.
- Reuse generated GraphQL types rather than hand-copying server shapes — a hand-typed
  duplicate silently drifts.
- Derive rather than duplicate: `Pick`, `Omit`, `Parameters`, `ReturnType`,
  `keyof typeof`.
- `satisfies` when you want the literal type checked _and_ narrow:
  `const TONES = { ... } satisfies Record<Status, Tone>`.

---

## TS-5 (P1) — Nullability

- Don't mark a prop optional to dodge a compile error. `?` is a claim that callers
  may omit it — if they may not, make it required.
- `foo?.bar?.baz ?? fallback` chains three levels deep usually mean the type is wrong,
  or the value should have been narrowed once at the boundary.
- `!` non-null assertion is `as` in miniature. Prove it with a guard or an early
  return.
- Prefer `??` to `||` for defaults — `||` swallows `0` and `''`, a classic defect:

```ts
// ❌ a count of 0 becomes 10
const pageSize = props.pageSize || 10;
// ✅
const pageSize = props.pageSize ?? 10;
```

- **Repo hard rule:** never `||`-chain identifiers. `candidate.id || candidate.email`
  is forbidden — absent means `undefined`.

---

## TS-6 (P2) — Generics

- Generics that appear exactly once in a signature do nothing —
  `<T>(x: T): void` is `(x: unknown): void`.
- Constrain them: `<T extends { id: string }>`, not bare `<T>`.
- Meaningful names beat `T`/`U` past one parameter: `<TRow, TKey>`.
- If a generic exists so callers can pass `any` through, delete it.

---

## TS-7 (P2) — Event and DOM typing

- `React.ChangeEvent<HTMLInputElement>`, `React.MouseEvent<HTMLButtonElement>` —
  not `any`, not a hand-rolled `{ target: { value: string } }`.
- `React.ReactNode` for children; `React.ReactElement` for a return value.
- `useRef<HTMLDivElement>(null)` — type it, and handle `.current` being `null`.
- `React.ComponentProps<typeof Button>` to extend a component's props rather than
  restating them.

---

## Review prompts

1. Is there an `any`, an `as`, an `!`, or a `@ts-ignore` on a `+` line? Can each one
   be replaced with a guard?
2. Does every exported function, hook, and component declare its return type?
3. Do optional fields encode states that cannot co-occur? (→ union)
4. Is any default using `||` where `??` is meant?
5. Does any ID resolve through a fallback chain?
