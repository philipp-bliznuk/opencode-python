---
name: pr-checklist
description: >
  Pre-flight checklist before opening/merging a PR. Covers lint, tests, coverage,
  security scan, migration safety, commit hygiene. Load when preparing to open a PR.
---

# PR Pre-flight Checklist

Run through all sections. Every item must pass or be explicitly noted as acceptable.

## 1. Code Quality

```bash
uv run -- ruff check --config pyproject.toml .
uv run -- ruff format --config pyproject.toml --check .
uv run -- bandit -c pyproject.toml -r .
```

All three must exit 0. No suppressions (`# nosec`, `# noqa`) without documented justification.

## 2. Tests

```bash
uv run -- pytest
```

- All tests pass
- Coverage >= 95% (check `fail_under` in config)
- New code has corresponding tests
- No skipped tests without reason

## 3. Type Completeness

- All new/modified public functions have full type annotations
- No `Any` without documented reason
- No `Optional` -- must be `X | None`
- Type-only imports in `TYPE_CHECKING` blocks

## 4. Migrations (if applicable)

- [ ] `alembic upgrade head` succeeds on clean DB
- [ ] `alembic downgrade -1` + `upgrade head` round-trips cleanly
- [ ] All constraints named explicitly
- [ ] All FKs have `ondelete="CASCADE"`
- [ ] No `ADD COLUMN NOT NULL` without `server_default` on populated table
- [ ] Large table indexes use `CONCURRENTLY`

## 5. Security

- [ ] No hardcoded secrets/keys/tokens
- [ ] No raw SQL strings (parameterized only)
- [ ] Auth applied on new endpoints
- [ ] No `print()` statements leaking data
- [ ] Dependencies: `uv lock` did not introduce known CVEs

## 6. Commit Hygiene

- [ ] Commits follow Conventional Commits format
- [ ] No merge commits (rebase-based)
- [ ] No WIP or fixup commits in final history
- [ ] Each commit is atomic -- single logical change

## 7. PR Description

Template:
```markdown
## Summary
<1-3 bullets: what changed and why>

## Changes
<significant files and what changed>

## Testing
<how tested, or why no tests needed>

## Notes
<anything reviewer should watch for>
```

## 8. Final

```bash
make check  # full quality gate
```

If all pass: ready to open PR.
If any fail: fix before opening. Never open PR with known failures.
