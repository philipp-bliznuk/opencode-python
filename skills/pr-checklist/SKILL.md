---
name: pr-checklist
description: Full pre-flight checklist before opening a pull request. Covers code quality, tests, coverage, migrations, environment variables, commit messages, branch naming, and PR description. Load this when the user asks to open a PR, prepare a PR, or says the work is ready to merge.
license: MIT
compatibility: opencode
---

# Skill: PR Pre-Flight Checklist

Run every item below in order. Do not open the PR until all blockers are resolved.

---

## 1. Branch name

Confirm the current branch follows the convention:

| Prefix | For |
|---|---|
| `feature/` | New functionality |
| `bug/` or `fix/` | Bug fixes |
| `hotfix/` | Urgent production fixes |
| `chore/` | Dependency bumps, config changes |
| `docs/` | Documentation only |

```bash
git branch --show-current
```

If the branch name is wrong, rename it now — it affects the auto-labeler:

```bash
git branch -m old-name new-name
git push origin :old-name new-name
git push --set-upstream origin new-name
```

---

## 2. Full quality gate

```bash
make check
```

This runs `fmt` → `lint_ruff` → `lint_bandit` → `test` → `pre_commit_run` in sequence. All must pass clean. If `make` is not present, run manually:

```bash
uv run -- ruff format --config pyproject.toml .
uv run -- ruff check --config pyproject.toml .
uv run -- bandit -c pyproject.toml -r .
uv run -- pytest
uv run -- pre-commit run -a
```

**Zero warnings, zero violations, zero test failures required.**

---

## 3. Coverage

```bash
uv run -- pytest --cov-report=term-missing
```

Coverage must be ≥ 95% on the source directory. If below threshold:

1. Open `coverage/index.html` to identify uncovered lines
2. Write tests for the uncovered code — do not exclude lines with `# pragma: no cover` unless they are genuinely untestable (e.g. `if __name__ == "__main__"`)
3. Re-run until threshold is met

---

## 4. No suppressions introduced

Search for any suppressions added in this branch:

```bash
git diff origin/$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|origin/||')...HEAD -- '*.py' | grep '^\+' | grep -E '# nosec|# noqa|# type: ignore'
```

Any new suppression is a blocker. Remove it and fix the underlying issue instead.

---

## 5. Docstrings on new public API

For every new public function, method, or class added in this branch, confirm a Google-style docstring is present:

```bash
git diff origin/$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|origin/||')...HEAD --name-only -- '*.py'
```

Open each changed file and verify. Per `AGENTS.md`: required on public functions, methods, and classes. Not required on `__init__`, magic methods, modules, or packages.

---

## 6. Environment variables

If any new environment variable was added:

```bash
git diff origin/$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|origin/||')...HEAD -- '.env.example'
```

`.env.example` must be updated with the new variable (empty value or safe default). Missing `.env.example` entries are a blocker — the next developer to clone the repo will get a cryptic validation error.

---

## 7. Lockfile committed

If any dependency was added or updated:

```bash
git status uv.lock
```

`uv.lock` must be staged and committed. If it shows as modified but unstaged:

```bash
uv lock
git add uv.lock
git commit --amend --no-edit   # only if the last commit was yours and not yet pushed
```

---

## 8. Migrations reviewed

If any `migrations/versions/` files were added or modified:

```bash
git diff origin/$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|origin/||')...HEAD --name-only -- 'migrations/'
```

For each migration file, verify (load `alembic-migration` skill for the full checklist):
- All constraints are named
- `downgrade()` is complete and reversible
- No `ADD COLUMN NOT NULL` without `server_default` on a non-empty table
- No unlocked index creation on large tables

---

## 9. Commit message quality

Review all commits that will be included in the PR:

```bash
git log --oneline origin/$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|origin/||')...HEAD
```

Every commit must follow Conventional Commits:
- `feat(scope): add item creation endpoint`
- `fix(auth): prevent token reuse after logout`
- `chore(deps): bump ruff to 0.15`
- `refactor(controller): extract pagination logic`

Fix any vague messages (`fix bug`, `update`, `wip`) before the PR is opened:

```bash
git rebase -i origin/<base-branch>   # reword commits interactively
```

Only rebase commits that have not been pushed to remote.

---

## 10. PR description

Fill in every section of the template. Do not leave sections empty or write "N/A":

```markdown
## Summary
- <What changed and why — 1-3 bullet points>

## Changes
- `path/to/file.py` — <what changed>
- `migrations/versions/...` — <what the migration does> (if applicable)

## Testing
- <How was this tested? Unit tests? Manual testing? Both?>
- <Coverage: X% (was Y%)>

## Notes
- <Anything the reviewer should pay particular attention to>
- <Known limitations or follow-up work>
```

---

## 11. Final pre-push verification

```bash
git diff --stat origin/$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|origin/||')...HEAD
git log --oneline origin/$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|origin/||')...HEAD
```

Confirm:
- The diff is what you expect — no accidental files, no leftover debug code
- The commit list is clean — no merge commits from pulling base branch mid-branch (use rebase)
- Target branch is correct (not accidentally targeting `prod` when you meant `dev`)

---

## 12. Push and open

```bash
git push -u origin $(git branch --show-current)
gh pr create --title "<type>(<scope>): <summary>" --body "$(cat <<'EOF'
## Summary
...
## Changes
...
## Testing
...
## Notes
...
EOF
)"
```

After opening, confirm:
- GitHub Actions PR check triggered and passing
- Auto-labels applied correctly by the labeler
- CODEOWNERS review requested automatically
