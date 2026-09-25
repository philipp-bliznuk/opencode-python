---
name: alembic-migration
description: Alembic migration workflow — autogenerate, constraint naming, enum changes, big-table indexes, reversibility. Load when changing SQLModel models or schema.
---

## Pre-flight
- `migrations/env.py` imports all model packages (missing model → empty migration).
- PG enums: `import alembic_postgresql_enum` in `env.py`.
- `uv run -- alembic current && uv run -- alembic history --verbose`

## Generate
`uv run -- alembic revision --autogenerate -m "<slug>"` — snake_case imperative, e.g. `add_items_table`.

## Review generated file
- Names: FK `<table>_<col>_fkey`, unique `unique_<table>_<cols>`, index `ix_<table>_<col>`. No `None`.
- `downgrade()` exact inverse. Never `pass`; `raise NotImplementedError` if truly unsafe.
- Every FK `ondelete='CASCADE'`.
- Rename detected as drop+add → replace with `op.alter_column(..., new_column_name=...)`.
- `ADD COLUMN NOT NULL` on populated table → `server_default` or two-phase (nullable → backfill → NOT NULL).
- Enum change → `sync_enum_values`, not raw `ALTER TYPE`.
- Big-table index:
```python
with op.get_context().autocommit_block():
    op.create_index("ix_items_company_id", "items", ["company_id"], postgresql_concurrently=True)
```

## Apply
`uv run -- alembic upgrade head && uv run -- alembic current && uv run -- pytest`
