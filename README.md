# review-skills

Claude Code skills for reviewing and writing React/TypeScript code.

## Skills

### `react-code-quality`

The rules layer for React code review — what good looks like, as ~68 numbered rules,
each written as **smell → why it's a defect → the fix**.

Use it in two directions:

- **Reviewing** — a PR, a diff, or code that was just generated.
- **Writing** — read the relevant reference file *before* writing, so the code lands
  clean the first time.

| File | Covers |
| --- | --- |
| `SKILL.md` | Prime directive, severity tiers, Conventional Comments format, the 4-pass review workflow, the 12 gates, rule index |
| `CHECKLIST.md` | Copy-paste pass/fail gate for a PR |
| `reference/hooks.md` | **Hook necessity test** (`HK-1`), Rules of Hooks, custom-hook API design |
| `reference/effects.md` | 14-pattern `useEffect` anti-pattern catalogue with a triage tree |
| `reference/state.md` | Derived state, single source of truth, impossible states, colocation, Context |
| `reference/components.md` | Component identity, size, props API, keys, conditional rendering |
| `reference/clean-code.md` | The abstraction bar, naming, control flow, errors, dead code, tests |
| `reference/typescript.md` | Type honesty, unions over optional soup, nullability |
| `reference/performance.md` | Memoisation *correctness* — not "add `useMemo` everywhere" |
| `reference/async-data.md` | The four states, race conditions, error handling |

**The headline rule (`HK-1`):** a function is a hook **if and only if it calls another
hook.** A `use*` function that calls no hook is a plain function wearing a hook
costume — it forces the Rules of Hooks onto every caller, blocks conditional and
in-handler calls, needs `renderHook` to test, and hides that the logic is pure.

## Install

Clone once, symlink into Claude Code's user-level skills directory, and every
workspace on the machine picks it up:

```bash
git clone https://github.com/anasmallick35/review-skills.git ~/.claude/skills-src/review-skills
~/.claude/skills-src/review-skills/install.sh
```

`install.sh` symlinks each skill into `~/.claude/skills/`, so a `git pull` in the
clone updates every workspace at once.

To pull updates later:

```bash
cd ~/.claude/skills-src/review-skills && git pull
```

### Project-level install instead

To vendor the skill into one repo (so teammates and CI-side worktrees get it too),
copy rather than symlink:

```bash
cp -R ~/.claude/skills-src/review-skills/react-code-quality <repo>/.claude/skills/
```

A project-level skill takes precedence over the user-level one of the same name.

## Adapting to a non-Talview repo

Most of the rubric is framework-level and portable as-is. These parts are specific to
the `talview/webclients` monorepo — delete or rewrite them for another codebase:

- `SKILL.md` → the **"Repo hard rules"** section and the **"Composition with other
  skills"** table.
- `CHECKLIST.md` → the **"Repo hard rules"** block.
- References to `@teserra/*`, `@packages/store`, `@packages/logger`, `@packages/i18n`,
  `modules/*`, `v8/`, and named sibling skills (`teserra-components`,
  `state-management`, `e2e-expert`, …).

Everything under `HK-*`, `EF-*`, `ST-*`, `CP-*`, `CC-*`, `TS-*`, `PF-*`, and most of
`AD-*` applies to any React codebase.

## Sources

Merged and distilled from:

- [awesome-skills/code-review-skill](https://github.com/awesome-skills/code-review-skill) — severity tiers, 4-phase process, React 19 rules
- [victor36max/use-effect-killer](https://github.com/victor36max/use-effect-killer) — the effect anti-pattern catalogue
- [React — You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)
- [React — Reusing Logic with Custom Hooks](https://react.dev/learn/reusing-logic-with-custom-hooks) — the `use`-prefix rule
- [Google engineering practices — What to look for in a code review](https://google.github.io/eng-practices/review/reviewer/looking-for.html) — the code-health principle and review ordering
- [Conventional Comments](https://conventionalcomments.org/) — comment format
- [formidablelabs/eslint-plugin-no-unnecessary-hook-definition](https://github.com/formidablelabs/eslint-plugin-no-unnecessary-hook-definition)
- [Pagepro](https://pagepro.co/blog/18-tips-for-a-better-react-code-review-ts-js/) and [Kodus](https://kodus.io/en/react-code-review-checklist) React review checklists
