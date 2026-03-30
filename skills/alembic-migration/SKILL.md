---
name: alembic-migration
description: Step-by-step workflow for creating, reviewing, and applying Alembic migrations safely. Covers autogenerate, constraint naming, enum changes, large-table indexes, reversibility checks, and common pitfalls. Load this when the user asks to add a migration, modify a SQLModel model, or make any schema change.
license: MIT
compatibility: opencode
---

# Skill: Alembic Migration Workflow

## Pre-flight checks

Before running `alembic revision`, verify the following or the autogenerate output will be incomplete or wrong.

### 1. Model discovery

Open `migrations/env.py` and confirm `_import_all_models()` is present and walks `api.models` (or your package's models directory):

```python
def _import_all_models() -> None:
    import api.models
    for _, name, _ in pkgutil.walk_packages(api.models.__path__, api.models.__name__ + "."):
        importlib.import_module(name)

_import_all_models()
```

If a model is not imported before `SQLModel.metadata` is read, autogenerate will not see it and will silently generate an empty migration. Add any new model files to the package before proceeding.

### 2. Enum support

If the migration involves a PostgreSQL enum (any `StrEnum` or `IntEnum` field on a table model), confirm `alembic_postgresql_enum` is imported at the top of `migrations/env.py`:

```python
import alembic_postgresql_enum  # noqa: F401 — side-effect import
```

If it is missing, add it and install the package: `uv add alembic-postgresql-enum`.

### 3. DB is reachable and current

```bash
uv run -- alembic current        # should show current revision
uv run -- alembic history --verbose  # review existing chain
```

If `alembic current` shows `(head)` but the models have changed, you are ready to autogenerate. If it shows an unapplied revision, apply it first: `uv run -- alembic upgrade head`.

---

## Step 1 — Generate the migration

```bash
uv run -- alembic revision --autogenerate -m "<slug>"
```

Slug conventions:
- Use snake_case, imperative mood, max ~6 words
- Good: `add_items_table`, `add_company_id_to_boats`, `rename_status_to_state`
- Bad: `migration`, `update`, `fix`

The generated file will be at `migrations/versions/YYYYMMDDhhmm_<slug>.py` and will be auto-linted and formatted by the `alembic.ini` post-write hooks.

---

## Step 2 — Review the generated file

Open the file immediately. Read both `upgrade()` and `downgrade()` in full. Work through this checklist:

### Constraint naming
Every constraint must have an explicit name. Flag and fix any `None` values:

```python
# BAD — Alembic generated a random or None name
sa.UniqueConstraint('name', 'company_id')

# GOOD — explicit name following the convention
sa.UniqueConstraint('name', 'company_id', name='unique_item_name_company_id')
```

Naming convention: `<table>_<column(s)>_<type>`
- Foreign key: `item_company_id_fkey`
- Unique: `unique_item_name_company_id`
- Index: `ix_item_company_id`
- Check: `ck_item_status`

### Reversibility
`downgrade()` must be the exact inverse of `upgrade()`:
- `create_table` ↔ `drop_table`
- `add_column` ↔ `drop_column`
- `create_index` ↔ `drop_index`
- `create_unique_constraint` ↔ `drop_constraint`
- Enum additions ↔ `sync_enum_values` removal

Never leave `downgrade()` with a `pass` body. If a downgrade is genuinely unsafe (e.g. data loss), add an explicit `raise NotImplementedError` with a comment explaining why, rather than silent `pass`.

### Cascade on foreign keys
All `ForeignKeyConstraint` entries must include `ondelete="CASCADE"`:
```python
# BAD
sa.ForeignKeyConstraint(['company_id'], ['company.id'], name='item_company_id_fkey')

# GOOD
sa.ForeignKeyConstraint(['company_id'], ['company.id'], name='item_company_id_fkey', ondelete='CASCADE')
```

### Autogenerate false positives to ignore
Alembic sometimes generates noise. Safe to delete from the migration if the intent is clear:
- `server_default` changes on columns that already have data (can cause issues)
- `comment` changes if you don't use column comments
- Changes to `sa.Text` vs `sa.String` that are cosmetic

---

## Step 3 — Safety checks for specific operations

### Adding a NOT NULL column to an existing table

This is dangerous in production — it will fail if any existing row has no value for the new column. Two options:

**Option A — two-phase migration (preferred for large tables):**
```python
# Migration 1: add column as nullable
op.add_column('items', sa.Column('new_field', sa.String(), nullable=True))

# Migration 2 (after backfill): make it NOT NULL
op.alter_column('items', 'new_field', existing_type=sa.String(), nullable=False)
```

**Option B — add with server_default (safe for immediate rollout):**
```python
op.add_column('items', sa.Column(
    'new_field', sa.String(),
    nullable=False,
    server_default=sa.text("''")  # safe empty default; remove in next migration
))
```

### Adding an index to a large table

A standard `CREATE INDEX` locks the table. Use `CONCURRENTLY` with an `autocommit_block`:

```python
def upgrade() -> None:
    with op.get_context().autocommit_block():
        op.create_index(
            'ix_items_company_id',
            'items',
            ['company_id'],
            postgresql_concurrently=True,
        )

def downgrade() -> None:
    with op.get_context().autocommit_block():
        op.drop_index(
            'ix_items_company_id',
            table_name='items',
            postgresql_concurrently=True,
        )
```

### Enum changes (adding a value)

Adding a value to a PostgreSQL enum is not reversible by default. `alembic_postgresql_enum` handles this automatically in autogenerate. Verify the generated migration uses `sync_enum_values` rather than raw `ALTER TYPE`:

```python
# What alembic_postgresql_enum generates — correct:
from alembic_postgresql_enum import sync_enum_values

def upgrade() -> None:
    sync_enum_values('public', 'itemstatus', ['active', 'inactive', 'archived'],
                     affected_columns=[('items', 'status')], ...)
```

If the migration uses raw `op.execute("ALTER TYPE itemstatus ADD VALUE 'archived'")`, that is fine but **not reversible** — ensure `downgrade()` uses `sync_enum_values` to remove the value.

### Renaming a column or table

Autogenerate detects renames as `drop + add`, which loses data. Replace it with:

```python
# Column rename
op.alter_column('items', 'old_name', new_column_name='new_name')

# Table rename
op.rename_table('old_items', 'items')
```

Flag this as a **zero-downtime concern**: if any deployed instance still references the old name, you need a two-phase approach (keep both names until fully deployed).

---

## Step 4 — Apply locally and verify

```bash
uv run -- alembic upgrade head
uv run -- alembic current    # confirm shows (head)
```

If the migration fails, fix the migration file (do not create a new revision on top of a broken one). Then:

```bash
uv run -- alembic downgrade -1
# fix the migration file
uv run -- alembic upgrade head
```

---

## Step 5 — Run the test suite

```bash
uv run -- pytest
```

The test suite creates its own schema from metadata (`SQLModel.metadata.create_all`) — it does not run migrations. A successful test run confirms the models are consistent. If tests fail with `ProgrammingError: column does not exist`, the model was updated but the migration is missing a change.

---

## Common mistakes checklist

- [ ] New model file not imported by `_import_all_models()` → autogenerate misses the table
- [ ] `alembic_postgresql_enum` not imported → enum changes not detected
- [ ] Constraint has no name (autogenerate left `None`) → will fail on PostgreSQL
- [ ] FK missing `ondelete="CASCADE"` → orphaned rows on parent delete
- [ ] `downgrade()` is `pass` or incomplete → rollbacks broken
- [ ] `CREATE INDEX` without `CONCURRENTLY` on a large table → production table lock
- [ ] `ADD COLUMN NOT NULL` without `server_default` on a populated table → migration fails
- [ ] Rename detected as drop+add → data loss
