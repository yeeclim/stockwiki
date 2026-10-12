# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. JS/TS Anti-Slop Rules

**Reject low-evidence code. Types and data must be proven, not asserted.**

Distilled from [dmmulroy/anti-slop](https://github.com/dmmulroy/anti-slop) (Oxlint ruleset, not installed — follow as policy). Applies to code you write or modify in `api/`, `scripts/`, `supabase/functions/`; do not rewrite untouched code to comply (see §3).

Data at boundaries:
- Parse external input (request body, API/DB responses) once at the boundary into a known structure. No scattered ad-hoc `typeof` checks deep in logic.
- No `Reflect.get` / `Reflect.apply` — use typed property access and direct calls.

Types (TS — `supabase/functions/`):
- No `unknown` / `object` / `Record<string, unknown|any>` on function parameters, return types, or dictionary values. Exception: `catch`/`cause` and the subject of a type predicate.
- Don't widen a known value to `unknown`/`any`/broad record and assert it back later.
- No chained assertions (`x as object as User`). Every non-`as const` assertion needs a `// SAFETY:` comment stating the invariant.

Collections:
- No `.filter().map()` / `.map().filter()` double passes on hot paths — use one `flatMap` or a single loop.
- In `reduce`, mutate a fresh local accumulator; never copy it per iteration (`{...acc}`, `[...acc]`, `concat`, `slice`, `Object.assign({}, acc, …)`).

Objects:
- No `...(cond ? { k: v } : {})` to omit fields — assign explicitly; omission ≠ `undefined`.

Tests:
- No module mocking (`vi.mock`, `jest.mock`). Inject real dependency seams instead.

Readability:
- Blank line between top-level declarations, around multiline bindings, before `return`/control flow, and after blocks.
- Don't put `shape` in symbol names — name what the thing is.

## 6. Verification Before Completion

**No completion claims without fresh verification evidence.**

Adapted from [obra/superpowers verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md).

Before saying done / fixed / passing — and before commit, push, or PR:
1. Identify the command that proves the claim.
2. Run it in full, now. A previous run doesn't count.
3. Read the output: exit code, failure count.
4. Report the actual state with the evidence. If it fails, say so with the output.

| Claim | Requires | Not sufficient |
|-------|----------|----------------|
| Tests pass | Test output: 0 failures | "Should pass", earlier run |
| Build succeeds | Build exit 0 | Lint passing |
| Bug fixed | Original symptom reproduced, now passes | Code changed |
| Regression test works | Red-green: fails without fix, passes with it | Passes once |
| Subagent finished | `git diff` shows the changes | Agent's success report |
| Requirements met | Line-by-line check against the request | Tests passing |

Project commands:
- Flutter: `flutter analyze`, `flutter test`
- API: `npm run test:api`
- Python (`trading/`, no test suite): `python -m py_compile <changed files>` at minimum; run the touched script's dry-run/import path when one exists.
- GitHub Actions: changes must be committed **and pushed** before a workflow run can verify them. Test paths that send email or touch real accounts via an isolated `workflow_dispatch` workflow, not the production one.

If no command can verify a claim, say "not verified" and why. Words like "should", "probably", "seems to" before a completion claim mean verification is missing.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
