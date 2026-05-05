---
name: alembic-migration
description: >
  Step-by-step Alembic migration workflow. Covers autogenerate, constraint naming, enum changes,
  large-table indexes, reversibility. Load when creating/modifying SQLModel models or schema changes.
---

# Alembic Migration Workflow

## Pre-flight

1. **Model discovery** -- confirm `_import_all_models()` in `migrations/env.py` walks all model packages. Missing model = silent empty migration.

2. **Enum support** -- if migration involves PG enum, confirm `import alembic_postgresql_enum` in `env.py`. Missing = enum changes not detected.

3. **DB current** -- run:
```bash
uv run -- alembic current
uv run -- alembic history --verbose
```

## Generate

```bash
uv run -- alembic revision --autogenerate -m "<slug>"
```

Slug: snake_case, imperative, max ~6 words. Good: `add_items_table`. Bad: `migration`.

## Review Generated File

### Constraint Naming
Every constraint needs explicit name. Fix any `None`:
- FK: `<table>_<col>_fkey`
- Unique: `unique_<table>_<cols>`
- Index: `ix_<table>_<col>`

### Reversibility
`downgrade()` = exact inverse of `upgrade()`. Never `pass` body -- use `raise NotImplementedError` if genuinely unsafe.

### Cascade
All `ForeignKeyConstraint` must have `ondelete='CASCADE'`.

## Safety Checks

### ADD COLUMN NOT NULL (populated table)
Option A: Two-phase (add nullable, backfill, alter to NOT NULL).
Option B: Add with `server_default`.

### Index on large table
```python
def upgrade() -> None:
    with op.get_context().autocommit_block():
        op.create_index('ix_items_company_id', 'items', ['company_id'],
                       postgresql_concurrently=True)
```

### Enum changes
Verify uses `sync_enum_values` from `alembic_postgresql_enum`, not raw `ALTER TYPE`.

### Column/table rename
Autogenerate detects as drop+add (data loss). Replace with `op.alter_column(..., new_column_name=...)`.

## Apply + Verify

```bash
uv run -- alembic upgrade head
uv run -- alembic current
uv run -- pytest
```

## Common Mistakes

- New model file not imported -> autogenerate misses table
- `alembic_postgresql_enum` not imported -> enum changes missed
- Constraint has no name -> fails on PostgreSQL
- FK missing `ondelete="CASCADE"` -> orphaned rows
- `CREATE INDEX` without `CONCURRENTLY` on large table -> table lock
- `ADD COLUMN NOT NULL` without `server_default` -> migration fails
- Rename detected as drop+add -> data loss
