---
name: pr-checklist
description: Pre-merge gate — lint, tests, coverage, security, migration safety, commit hygiene. Load when preparing a PR.
---

All pass or explicitly noted.

## 1. Quality
```bash
uv run -- ruff check --config pyproject.toml .
uv run -- ruff format --config pyproject.toml --check .
uv run -- bandit -c pyproject.toml -r .
uv run -- pytest
```
Exit 0. No `# noqa`/`# nosec`. Coverage ≥ 95%. No unexplained skips.

## 2. Types
Full annotations on new public funcs. No `Any` w/o reason. `X | None`. Type-only imports in `TYPE_CHECKING`.

## 3. Migrations
`upgrade head` on clean DB · `downgrade -1` + `upgrade head` round-trip · constraints named · FKs CASCADE · no NOT NULL w/o `server_default` · big-table index CONCURRENTLY.

## 4. Security
No hardcoded secrets · no raw SQL strings · auth on new endpoints · no `print` · `uv lock` no new CVEs.

## 5. Commits
Conventional Commits · rebased, no merge/WIP/fixup · atomic.

## 6. Description
```markdown
## Summary
## Changes
## Testing
## Notes
```

## 7. `make check` → green → open PR.
