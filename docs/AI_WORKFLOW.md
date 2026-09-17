# AI-Assisted Development Workflow

**How iShamela is built:** specifications first, code second. This document explains how developers use the repo's specs and AI-context assets with Cursor, Claude Code, or similar tools.

## The model

```
Project management (Claude, this layer)
        │  produces
        ▼
Specs & ADRs (docs/specs/, docs/adr/)  +  AI context (CLAUDE.md, .cursor/rules/, .claude/skills/)
        │  consumed by
        ▼
Developers + AI coding tools (Cursor, Claude Code, ...)
        │  produce
        ▼
Code + tests, PR-reviewed against the spec
```

Rules of the game:

1. **No feature without a spec.** If you're about to prompt your AI tool to build something that has no `SPEC-xxx`, stop and request one (open an issue with the `needs-spec` label).
2. **The spec is the acceptance test.** A PR is done when every "Acceptance criteria" checkbox in its spec passes — not when the code "looks right".
3. **Specs are versioned, code follows.** If implementation reveals the spec is wrong, the spec gets a PR first; then code.
4. **Golden files are law.** Shared test vectors (e.g., `test_vectors.jsonl` for the normalizer) may only change via a spec update.

## Repository AI assets

| File | Tool | Purpose |
|---|---|---|
| `CLAUDE.md` | Claude Code (auto-loaded) | Project context, commands, conventions, guardrails |
| `.cursor/rules/*.mdc` | Cursor (auto-attached by glob) | Same context, split by concern |
| `.claude/skills/arabic-text/` | Claude Code skill | Deep reference for Arabic text handling, loaded on demand |
| `docs/specs/SPEC-*.md` | All (referenced in prompts) | Implementation contracts |
| `docs/adr/*.md` | All | Why decisions were made — prevents AI tools "helpfully" re-deciding |

## How to prompt your tool (recommended loop)

1. **Open with the spec:** "Implement `docs/specs/SPEC-002-bundle-builder.md`. Read it fully, read ADR-001, then propose a file-by-file plan before writing code."
2. **Demand the plan first.** Review it against the spec yourself — this is where drift is cheapest to catch.
3. **Tests before features:** ask the tool to write the acceptance tests from the spec's criteria first, watch them fail, then implement.
4. **One spec = one PR.** Keep diffs reviewable.
5. **Paste back failures, not descriptions.** Give the tool raw test/CI output.

Anti-patterns to refuse:
- The tool inventing schema fields, dataset paths, or normalization rules not in the spec ("plausible" ≠ specified).
- Silent dependency additions — every new dependency is named in the PR description with a one-line justification.
- Touching displayed text (`body`) with normalization — normalization exists **only** in `body_norm` and query processing (ADR-001).

## Definition of Done (every PR)

- [ ] Linked spec's acceptance criteria all pass (CI green).
- [ ] No changes to golden files unless the PR also updates the spec.
- [ ] New/changed public functions have docstrings referencing the spec section they implement.
- [ ] `CHANGELOG.md` entry under *Unreleased*.
