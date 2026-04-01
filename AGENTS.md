# Python Project Standards

This document defines the coding standards, tooling configuration, and architectural patterns for all Python projects. It is the authoritative reference for any AI agent or developer starting or contributing to a Python project in this workspace.

**How to use this document:**
- All tooling, configuration values, and code patterns in this document are **non-negotiable defaults**. Apply them without asking.
- Sections marked with a **"Ask the user"** note contain decisions that depend on project specifics. Pause and ask before proceeding in those cases.
- When in doubt about a domain decision not covered here, use your best judgment and document what you chose and why in a `CLAUDE.md` at the project root.

---

## Table of Contents

1. [Before You Start](#1-before-you-start)
2. [Toolchain](#2-toolchain)
3. [pyproject.toml Reference](#3-pyprojecttoml-reference)
4. [ruff.toml Local Override](#4-rufftoml-local-override)
5. [Code Style Rules](#5-code-style-rules)
6. [Project Layout](#6-project-layout)
7. [FastAPI Patterns](#7-fastapi-patterns)
8. [Data Layer](#8-data-layer)
9. [Pydantic Schemas](#9-pydantic-schemas)
10. [Dependencies](#10-dependencies)
11. [Testing](#11-testing)
12. [Pre-commit Hooks](#12-pre-commit-hooks)
13. [CI/CD](#13-cicd)
14. [Container & Deployment](#14-container--deployment)
15. [Environment Variables](#15-environment-variables)
16. [Makefile](#16-makefile)

---

## 1. Before You Start

Before writing any code for a new project, ask the user the following questions if the answers are not already clear from the context:

1. **Deployment target** — FastAPI web service (Docker/ECS) or Lambda function (AWS SAM)? This determines the project layout, dependency setup, and deployment workflow.
2. **Database** — PostgreSQL (via SQLModel + asyncpg), no DB, or something else?
3. **Authentication** — what is the auth provider and mechanism (e.g. Auth0 JWT, API key, OIDC, none)?
4. **Testing scope** — is a full test suite expected, or is this a small utility where tests are out of scope?

Everything else in this document applies unconditionally.

---

## 2. Toolchain

These tools are mandatory for every project. No alternatives.

| Concern | Tool | Notes |
|---|---|---|
| Python version | **3.14** | Pin with `.python-version` file containing `3.14` |
| Package manager | **uv** | Only tool for installing, locking, and running. No pip, poetry, or pipenv. |
| Linter | **ruff** | Full rule set, preview mode, auto-fix enabled |
| Formatter | **ruff format** | Replaces black and isort |
| Security scanner | **bandit** | Strict profile, no suppressions |
| Pre-commit | **pre-commit** | All hooks must pass before every commit |
| Debug printing | **icecream** | Use `ic()` instead of `print()` during development |

### uv Conventions

```bash
# Bootstrap a new project
uv init --no-package

# Install all dependencies (development)
uv sync --frozen

# Install without dev dependencies (production / Docker)
uv sync --frozen --no-dev

# Add a dependency
uv add <package>

# Add a dev dependency
uv add --dev <package>

# Run a command inside the venv
uv run -- <command>

# Regenerate the lockfile after manual pyproject.toml edits
uv lock
```

- Always commit `uv.lock`. Never commit `.venv/`.
- Set `package = false` in `[tool.uv]` for non-library projects (services, lambdas).
- For multi-package repos, use uv workspaces: `[tool.uv.workspace]` with `members = [...]`.

### Standard dev dependency group

Every project has this baseline in `[dependency-groups]`:

```toml
[dependency-groups]
dev = [
    "bandit[toml]>=1.9",
    "icecream>=2.1",
    "pre-commit>=4.0",
    "ruff>=0.15",
]
```

For FastAPI web services, also add a `test` group (see [Section 11](#11-testing)).

---

## 3. pyproject.toml Reference

Below is the canonical configuration. Copy this into every new project and adjust only the values marked `# PROJECT-SPECIFIC`.

```toml
[project]
name = "your-project-name"          # PROJECT-SPECIFIC
version = "0.1.0"
requires-python = ">=3.14"
dependencies = []                   # PROJECT-SPECIFIC: add runtime deps here

[tool.uv]
package = false

[dependency-groups]
dev = [
    "bandit[toml]>=1.9",
    "icecream>=2.1",
    "pre-commit>=4.0",
    "ruff>=0.15",
]

# ── Ruff ──────────────────────────────────────────────────────────────────────

[tool.ruff]
line-length = 88
indent-width = 4
target-version = "py314"
output-format = "grouped"
cache-dir = ".ruff_cache"
preview = true
fix = true
show-fixes = true
unsafe-fixes = true
src = ["src"]                       # PROJECT-SPECIFIC: list your source roots

[tool.ruff.lint]
select = [
    "A",     # flake8-builtins
    "ANN",   # flake8-annotations
    "ARG",   # flake8-unused-arguments
    "ASYNC", # flake8-async
    "B",     # flake8-bugbear
    "BLE",   # flake8-blind-except
    "C4",    # flake8-comprehensions
    "C90",   # mccabe complexity
    "COM",   # flake8-commas
    "D",     # pydocstyle
    "DTZ",   # flake8-datetimez
    "E",     # pycodestyle errors
    "EM",    # flake8-errmsg
    "ERA",   # eradicate (no commented-out code)
    "EXE",   # flake8-executable
    "F",     # pyflakes
    "FBT",   # flake8-boolean-trap
    "FLY",   # flynt (f-string conversion)
    "G",     # flake8-logging-format
    "I",     # isort
    "ICN",   # flake8-import-conventions
    "INP",   # flake8-no-pep420
    "ISC",   # flake8-implicit-str-concat
    "LOG",   # flake8-logging
    "N",     # pep8-naming
    "PERF",  # perflint
    "PGH",   # pygrep-hooks
    "PIE",   # flake8-pie
    "PT",    # flake8-pytest-style
    "PTH",   # flake8-use-pathlib
    "PYI",   # flake8-pyi
    "Q",     # flake8-quotes
    "RET",   # flake8-return
    "RSE",   # flake8-raise
    "RUF",   # ruff-specific rules
    "S",     # flake8-bandit (security)
    "SIM",   # flake8-simplify
    "SLF",   # flake8-self
    "SLOT",  # flake8-slots
    "T10",   # flake8-debugger
    "T20",   # flake8-print
    "TCH",   # flake8-type-checking
    "TD",    # flake8-todos
    "TID",   # flake8-tidy-imports
    "TRY",   # tryceratops
    "UP",    # pyupgrade
    "W",     # pycodestyle warnings
    "YTT",   # flake8-2020
]
ignore = [
    "ANN101",  # missing-type-self (deprecated rule)
    "ANN102",  # missing-type-cls (deprecated rule)
    "ISC001",  # conflicts with ruff formatter
    "COM812",  # conflicts with ruff formatter
    "D100",    # module docstrings not required
    "D104",    # package docstrings not required
    "D105",    # magic method docstrings not required
    "D107",    # __init__ docstrings not required
    "TD003",   # TODO items don't need an issue link
    "RUF029",  # async functions without await are allowed
]
exclude = [".venv"]                 # PROJECT-SPECIFIC: add migrations/, etc.

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = [
    "INP001",  # not a package
    "D103",    # test functions don't need docstrings
    "S101",    # assert is expected in tests
    "PT012",   # pytest.raises can span multiple lines
    "SLF001",  # private member access is fine in tests
    "S105",    # hardcoded test passwords are fine
]
# PROJECT-SPECIFIC: add per-file ignores for migrations, scripts, etc.

[tool.ruff.lint.isort]
case-sensitive = true
combine-as-imports = true
force-sort-within-sections = true
length-sort = true
split-on-trailing-comma = false
lines-after-imports = 2
relative-imports-order = "closest-to-furthest"
known-first-party = ["src"]        # PROJECT-SPECIFIC: match your source roots

[tool.ruff.lint.flake8-bugbear]
# PROJECT-SPECIFIC: add FastAPI Depends/Query if using FastAPI
# extend-immutable-calls = ["fastapi.Depends", "fastapi.Query"]

[tool.ruff.lint.flake8-import-conventions]
banned-from = ["typing"]           # Never `from typing import X`; use `import typing as t`

[tool.ruff.lint.flake8-tidy-imports]
ban-relative-imports = "all"

[tool.ruff.lint.flake8-tidy-imports.banned-api]
"typing.Optional".msg = "Use `<type> | None` notation instead."

[tool.ruff.lint.flake8-type-checking]
strict = true
exempt-modules = ["typing", "typing_extensions"]
quote-annotations = false
# PROJECT-SPECIFIC: add runtime-evaluated base classes if using Pydantic/SQLAlchemy:
# runtime-evaluated-base-classes = ["pydantic.BaseModel", "sqlalchemy.orm.DeclarativeBase"]
# runtime-evaluated-decorators = ["pydantic.validate_call"]

[tool.ruff.lint.mccabe]
max-complexity = 4

[tool.ruff.lint.pydocstyle]
convention = "google"
ignore-decorators = ["typing.overload"]

[tool.ruff.lint.pylint]
max-args = 4
max-bool-expr = 3
max-branches = 5
max-nested-blocks = 3
max-positional-args = 3

[tool.ruff.lint.flake8-pytest-style]
parametrize-values-type = "tuple"

[tool.ruff.lint.pep8-naming]
classmethod-decorators = [
    "pydantic.validator",
    "pydantic.model_validator",
    # PROJECT-SPECIFIC: add SQLAlchemy declared_attr etc. if using ORM
]

[tool.ruff.format]
docstring-code-format = true
skip-magic-trailing-comma = true
preview = true
exclude = [".venv"]                # PROJECT-SPECIFIC: add migrations/ etc.

# ── Bandit ────────────────────────────────────────────────────────────────────

[tool.bandit]
targets = ["src"]                  # PROJECT-SPECIFIC: match your source roots
exclude_dirs = [".venv", "tests"]
recursive = true
skips = []
severity = "LOW"
confidence = "LOW"
context_lines = 3
allow_skipping = false             # # nosec comments are NOT allowed
profile = "strict"
aggregate = "vuln"

# ── Pytest (FastAPI web services only) ────────────────────────────────────────

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
timeout = 3
python_files = "test_*.py"
python_classes = "Test*"
filterwarnings = ["ignore::DeprecationWarning"]
addopts = """
  --cov=src
  --cov-report=html
  --cov-report=term
  --cov-append
  --cov-branch
  --capture=sys
  --durations=10
  --disable-warnings
  --tb=short
  --disable-socket
  --allow-unix-socket
  --allow-hosts=127.0.0.1,::1
  -n=auto
  --dist=loadfile
"""
# PROJECT-SPECIFIC: add -p no:<plugin> for any framework plugins you want to suppress

[tool.coverage.run]
concurrency = ["gevent", "thread"]
branch = true
source = ["src"]                   # PROJECT-SPECIFIC: match your source root
omit = ["*/tests/*", "*/.venv/*"]  # PROJECT-SPECIFIC: add generated/vendored paths

[tool.coverage.report]
fail_under = 95
precision = 2
show_missing = true
skip_covered = true
ignore_errors = true
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
    "if __name__ == .__main__.:",
    "pass",
    "@abc.abstractmethod",
    "if t.TYPE_CHECKING:",
]

[tool.coverage.html]
directory = "coverage"
```

---

## 4. ruff.toml Local Override

Place this file at the project root alongside `pyproject.toml`. It is picked up by IDE plugins (VS Code, PyCharm) but is **not** used in CI — CI always passes `--config pyproject.toml` explicitly.

The purpose is to prevent IDE auto-fix from silently removing unused imports and print statements during development, so they remain visible as warnings.

```toml
# ruff.toml — local/IDE override only
# CI uses pyproject.toml directly via --config pyproject.toml
extend = "./pyproject.toml"

[lint]
unfixable = [
    "F401",  # unused imports: show in IDE but don't auto-remove
    "T20",   # print statements: show in IDE but don't auto-remove
]
```

---

## 5. Code Style Rules

These rules are enforced by the ruff configuration above. They are listed here so an agent can apply them proactively without waiting for a lint failure.

### Imports

- Always use `import typing as t` — never `from typing import ...`
- All imports must be absolute — no relative imports at all
- Third-party type-only imports go in `if t.TYPE_CHECKING:` blocks
- Import order is managed by ruff/isort — run `ruff format` to fix

```python
# Correct
import typing as t
from collections.abc import AsyncGenerator

if t.TYPE_CHECKING:
    from mypackage.models import User

# Wrong
from typing import Optional, TYPE_CHECKING
from .models import User
```

### Type Annotations

- Every public function and method must have full type annotations (parameters + return type)
- Use `X | None` never `Optional[X]`
- Use `X | Y` never `Union[X, Y]`
- Use built-in generics: `list[str]`, `dict[str, int]`, `tuple[int, ...]` — not `List`, `Dict`, `Tuple`
- Use `t.Any`, `t.ClassVar`, `t.Annotated` — not `Any`, `ClassVar`, `Annotated` directly

```python
# Correct
def get_user(*, user_id: int, active: bool = True) -> User | None: ...

# Wrong
def get_user(user_id: int, active: bool = True) -> Optional[User]: ...
```

### Docstrings

- Google style, enforced by `pydocstyle`
- Required on all public functions, methods, and classes
- Not required on: `__init__`, magic methods, modules, packages, `@typing.overload` variants
- Code examples inside docstrings are formatted by `ruff format`

```python
def create_record(*, name: str, active: bool = True) -> Record:
    """Create and persist a new record.

    Args:
        name: The display name for the record.
        active: Whether the record is active on creation.

    Returns:
        The newly created record with all fields populated.

    Raises:
        DuplicateError: If a record with the same name already exists.
    """
```

### Complexity Limits

These are hard limits — if you hit them, the code needs to be refactored, not suppressed:

| Limit | Value |
|---|---|
| Cyclomatic complexity (McCabe) | 4 |
| Function arguments (total) | 4 |
| Function arguments (positional) | 3 |
| Boolean expressions in one condition | 3 |
| Branches per function | 5 |
| Nesting levels | 3 |

### Other Rules

- No commented-out code (`ERA` — eradicate). Delete it or use a TODO.
- No `print()` in production code. Use `ic()` from `icecream` during development; use `logging` in production.
- No `pdb`, `breakpoint()`, or debugger statements in committed code.
- No bare `except:` — always catch specific exceptions.
- All function arguments must be keyword-only where possible (use `*,` separator).
- Boolean arguments to functions are a code smell (`FBT` — flake8-boolean-trap). Use enums or separate functions.

---

## 6. Project Layout

### FastAPI Web Service

```
project-name/
├── .env                    # local secrets — git-ignored
├── .env.example            # committed template with all required keys
├── .github/
│   ├── CODEOWNERS
│   ├── labeler.yml
│   ├── actions/
│   │   └── setup_env/
│   │       └── action.yml
│   └── workflows/
│       ├── pr_check.yml
│       └── build_deploy.yml
├── .gitignore
├── .pre-commit-config.yaml
├── .python-version         # contains "3.14"
├── .ruff_cache/
├── .venv/
├── api/                    # application source (rename to match project)
│   ├── __init__.py
│   ├── controller.py       # generic repository + all controller singletons
│   ├── dependencies/       # FastAPI Depends functions + Annotated aliases
│   ├── enums.py            # all project enums
│   ├── exceptions.py       # custom exception hierarchy
│   ├── factories.py        # partial(model_factory, base=...) per model
│   ├── models/             # SQLModel table definitions
│   ├── routers/            # one module per resource; __init__.py has registry
│   ├── schemas/            # Pydantic request/response schemas
│   └── settings.py         # pydantic-settings Settings class + singleton
├── app.py                  # FastAPI app factory (create_app)
├── docker/
│   └── app/
│       ├── Containerfile
│       └── entrypoint.sh
├── compose.yml
├── gunicorn.conf.py
├── Makefile
├── migrations/             # Alembic (if using DB)
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
├── alembic.ini             # (if using DB)
├── pyproject.toml
├── ruff.toml
├── tests/
│   ├── conftest.py
│   └── ...                 # mirrors api/ structure
└── uv.lock
```

### AWS Lambda (SAM)

```
project-name/
├── .env
├── .env.example
├── .github/
│   ├── CODEOWNERS
│   ├── labeler.yml
│   ├── actions/setup_env/action.yml
│   └── workflows/
│       ├── pr_check.yml
│       └── deploy.yml
├── .gitignore
├── .pre-commit-config.yaml
├── .python-version
├── function_name/          # one directory per Lambda function
│   ├── main.py             # handler entry point
│   ├── pyproject.toml      # function-level deps
│   └── utils/
├── Makefile
├── pyproject.toml          # workspace root — dev tooling only
├── ruff.toml
├── samconfig.toml
├── template.yml            # SAM CloudFormation template
└── uv.lock
```

> **Ask the user** if the project doesn't fit either of these shapes before inventing a new structure.

---

## 7. FastAPI Patterns

### App Factory

Always use a `create_app()` factory function. Never create the app at module level directly.

```python
# app.py
from fastapi import FastAPI

from api import routers
from api.settings import settings
from api.enums import Environment


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    server = FastAPI(
        title="Project Name",
        version="0.1.0",
        debug=settings.ENV == Environment.LOCAL,
        # default_response_class is omitted — FastAPI 0.130+ uses Pydantic's
        # Rust-based serializer by default; ORJSONResponse is deprecated.
    )

    _set_routers(application=server)
    _set_middleware(application=server)

    return server


app = create_app()
```

Key decisions, all non-negotiable:
- No `default_response_class` — FastAPI 0.130+ uses Pydantic's Rust-based serializer by default, making `ORJSONResponse` unnecessary and deprecated
- `debug=True` only in `LOCAL` environment
- Routers, middleware, and startup tasks are set up in private helpers, not inline in `create_app()`

### Router Discovery

Use a `registry` list for dynamic router loading. This avoids a long chain of `include_router` calls and makes adding a new router a one-line change.

```python
# api/routers/__init__.py
registry = ["users", "items", "service"]  # PROJECT-SPECIFIC
```

```python
# api/routers/items/__init__.py  (for nested routers)
registry = ["item", "category", "tag"]
```

```python
# app.py
import importlib

def _import_routers(*, app: FastAPI, base_path: str, module_name: str) -> None:
    """Recursively import routers from registry lists."""
    module = importlib.import_module(f"{base_path}.{module_name}")
    if hasattr(module, "router"):
        app.include_router(module.router)
    if hasattr(module, "registry"):
        for sub in module.registry:
            _import_routers(app=app, base_path=f"{base_path}.{module_name}", module_name=sub)
```

### Router Structure

```python
# api/routers/items/item.py
from fastapi import APIRouter, status

router = APIRouter(prefix="/items", tags=["item"])


@router.get("/{item_id}", response_model=ItemResponse, status_code=status.HTTP_200_OK)
async def get_item(*, db: AsyncDBSession, item_id: int, user: RequestUser) -> ItemResponse:
    """Get a single item by ID."""
    item = await item_controller.get(db=db, current_user=user, id=item_id)
    if item is None:
        raise NotFoundError(detail=f"Item with id={item_id} not found.")
    return item


@router.post("/", response_model=ItemResponse, status_code=status.HTTP_201_CREATED)
async def create_item(*, db: AsyncDBSession, item: ItemCreate, user: RequireEditor) -> ItemResponse:
    """Create a new item."""
    ...


@router.patch("/{item_id}", response_model=ItemResponse)
async def update_item(*, db: AsyncDBSession, item_id: int, item: ItemUpdate, user: RequireEditor) -> ItemResponse:
    """Partially update an item."""
    ...


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(*, db: AsyncDBSession, item_id: int, user: RequireAdmin) -> None:
    """Delete an item."""
    ...
```

Rules:
- Always declare `response_model=` and `status_code=` on every endpoint decorator
- All endpoint function parameters must be keyword-only (`*,`)
- Apply auth dependencies at the endpoint level, not at the router level — different endpoints have different permission requirements
- Use `model_dump(exclude_unset=True)` on PATCH payloads so only provided fields are updated

### Middleware

Always add a global exception-catching middleware. It must be the first middleware added (innermost wrapper):

```python
def _set_middleware(*, application: FastAPI) -> None:
    """Configure application middleware."""
    @application.middleware("http")
    async def catch_exceptions_middleware(request: Request, call_next: Callable[..., t.Any]) -> Response:
        try:
            return await call_next(request)
        except Exception as exc:
            logging.getLogger(__name__).exception("Unexpected error")
            return JSONResponse(
                content={"detail": repr(exc)},
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    if settings.BACKEND_CORS_ORIGINS:
        application.add_middleware(
            CORSMiddleware,
            allow_origins=settings.BACKEND_CORS_ORIGINS,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
```

### Settings

One `Settings(BaseSettings)` class, one module-level singleton, configured at import time.

```python
# api/settings.py
from pydantic import AnyHttpUrl, PostgresDsn
from pydantic_settings import BaseSettings, SettingsConfigDict

from api.enums import Environment


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(arbitrary_types_allowed=True)

    ENV: Environment
    BACKEND_CORS_ORIGINS: list[str]
    APP_DOMAIN: AnyHttpUrl

    # PROJECT-SPECIFIC: add all required settings here with strong types
    # Use PostgresDsn for DB URIs, AnyHttpUrl for URLs, list[str] for lists


settings = Settings()
```

Rules:
- No `.env` path in code — pydantic-settings discovers it automatically
- Use typed fields: `PostgresDsn`, `AnyHttpUrl`, `list[str]` — not plain `str` for structured values
- Configure logging via `dictConfig()` at module import time in this file
- The singleton `settings = Settings()` validates all vars at startup — missing required vars raise immediately

### Exception Hierarchy

```python
# api/exceptions.py
from fastapi import HTTPException, status


class AppBaseError(HTTPException):
    """Base class for all HTTP exceptions in this project."""

    def __init__(self, *, status_code: int, detail: str, headers: dict[str, str] | None = None) -> None:
        """Initialize the error."""
        super().__init__(status_code=status_code, detail=detail, headers=headers)

    def __str__(self) -> str:
        """Return a string representation."""
        return f"{self.status_code}: {self.detail}"


class NotFoundError(AppBaseError):
    """Resource not found."""

    def __init__(self, *, detail: str) -> None:
        """Initialize the error."""
        super().__init__(status_code=status.HTTP_404_NOT_FOUND, detail=detail)


class AuthError(AppBaseError):
    """Authentication failed."""

    def __init__(self, *, detail: str) -> None:
        """Initialize the error."""
        super().__init__(status_code=status.HTTP_401_UNAUTHORIZED, detail=detail)


class PermissionDeniedError(AppBaseError):
    """Insufficient permissions."""

    def __init__(self, *, detail: str = "You don't have permission to perform this action.") -> None:
        """Initialize the error."""
        super().__init__(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


class BadRequestError(AppBaseError):
    """Invalid request."""

    def __init__(self, *, detail: str) -> None:
        """Initialize the error."""
        super().__init__(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


class ServerError(AppBaseError):
    """Internal server error."""

    def __init__(self, *, detail: str) -> None:
        """Initialize the error."""
        super().__init__(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=detail)
```

Rules:
- All HTTP-mapped exceptions extend `AppBaseError(HTTPException)` — FastAPI's built-in handler picks them up automatically, no custom exception handler registration needed
- Each subclass pins its own `status_code` and exposes only a `detail` parameter at the call site
- Non-HTTP internal exceptions (domain errors, integration errors) extend plain `Exception`

> **Ask the user** about the auth strategy, role model, and any domain-specific exception types before implementing them.

---

## 8. Data Layer

This section applies to projects using PostgreSQL with SQLModel. Skip it for Lambda-only projects without a DB.

### Base Model

All table models inherit from a `BaseModel` that provides `id`, `created_at`, `updated_at`, and auto-derives the table name:

```python
# api/models/base.py
import typing as t
from datetime import datetime

from pydantic import ConfigDict
from sqlalchemy import DateTime, func
from sqlmodel import Field, SQLModel

from api.utils.text import camel_to_snake


class BaseModel(SQLModel):
    """Base class for all SQLModel table definitions."""

    id: int = Field(primary_key=True, index=True, unique=True, nullable=False)
    created_at: datetime = Field(
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"default": func.now()},
        nullable=False,
        index=True,
    )
    updated_at: datetime = Field(
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"default": func.now(), "onupdate": func.now()},
        nullable=False,
        index=True,
    )

    @classmethod
    def __init_subclass__(cls, **kwargs: t.Unpack[ConfigDict]) -> None:
        """Auto-derive table name from class name."""
        super().__init_subclass__(**kwargs)
        cls.__tablename__ = camel_to_snake(text=cls.__name__)

    class Config:
        arbitrary_types_allowed = True
        validate_assignment = True
```

### Defining Models

```python
from sqlalchemy import ForeignKeyConstraint, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlmodel import Field, Relationship

from api.models.base import BaseModel


class Item(BaseModel, table=True):
    """An inventory item belonging to a company."""

    name: str = Field(index=True)
    description: str | None = Field(default=None)
    settings: dict[str, t.Any] = Field(sa_type=JSONB(), default={})
    company_id: int = Field(nullable=False)

    company: "Company" = Relationship(
        back_populates="items",
        sa_relationship_kwargs={"lazy": "selectin"},
    )

    __table_args__ = (
        ForeignKeyConstraint(
            ["company_id"], ["company.id"],
            name="item_company_id_fkey",
            ondelete="CASCADE",
        ),
        Index("ix_item_company_id", "company_id"),
    )
```

Rules:
- Every `table=True` model inherits from `BaseModel`
- All datetimes use `sa_type=DateTime(timezone=True)` — never naive datetimes
- JSON columns use `JSONB()` (PostgreSQL-specific, better indexing than JSON)
- All relationships set `lazy="selectin"` in `sa_relationship_kwargs` — no lazy loading (breaks async)
- All bidirectional relationships declare `back_populates` on both sides
- All foreign keys are explicitly named and use `ondelete="CASCADE"` — no soft delete by default
- All constraints are explicitly named (prevents Alembic from generating random names)
- No UUID primary keys on DB tables by default — use `int` auto-increment

### Enums

```python
# api/enums.py
from enum import StrEnum


class BaseEnum(StrEnum):
    """Base class for all project enums."""


class ItemStatus(BaseEnum):
    """Status of an inventory item."""

    ACTIVE = "active"
    INACTIVE = "inactive"
    ARCHIVED = "archived"
```

- All enums extend `BaseEnum(StrEnum)` for consistent string serialization
- Use `IntEnum` only when the integer value itself is meaningful (e.g. priority levels)
- Define all project enums in `api/enums.py`

### Generic Controller (Repository Pattern)

Use a single generic `Controller` class for all DB operations. Instantiate one singleton per model.

```python
# api/controller.py
import typing as t

from sqlalchemy import col, delete, func, insert, select, true, update, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import SQLModel

ModelType = t.TypeVar("ModelType", bound=SQLModel)


class Controller(t.Generic[ModelType]):
    """Generic async repository for SQLModel table models."""

    def __init__(self, *, model: type[ModelType]) -> None:
        """Initialize the controller with a model class."""
        self.model = model

    async def get(self, *, db: AsyncSession, **filters: t.Any) -> ModelType | None:
        """Fetch a single record matching the given filters."""
        result = await db.execute(select(self.model).where(self._where(**filters)))
        return result.scalars().one_or_none()

    async def list(self, *, db: AsyncSession, **filters: t.Any) -> list[ModelType]:
        """Fetch all records matching the given filters."""
        result = await db.execute(select(self.model).where(self._where(**filters)))
        return list(result.scalars().all())

    async def create(self, *, db: AsyncSession, record: dict[str, t.Any]) -> ModelType:
        """Insert a record and return the persisted instance."""
        result = await db.execute(
            insert(self.model).values(**record).returning(self.model)
        )
        await db.commit()
        return result.scalars().one()

    async def update(self, *, db: AsyncSession, record: dict[str, t.Any], **filters: t.Any) -> ModelType | None:
        """Update matching records and return the updated instance."""
        result = await db.execute(
            update(self.model).where(self._where(**filters)).values(**record).returning(self.model)
        )
        await db.commit()
        return result.scalars().one_or_none()

    async def delete(self, *, db: AsyncSession, **filters: t.Any) -> ModelType | None:
        """Delete matching records and return the deleted instance."""
        result = await db.execute(
            delete(self.model).where(self._where(**filters)).returning(self.model)
        )
        await db.commit()
        return result.scalars().one_or_none()

    async def exists(self, *, db: AsyncSession, **filters: t.Any) -> bool:
        """Return True if any record matches the given filters."""
        result = await db.execute(select(func.count(col(self.model.id))).where(self._where(**filters)))
        return (result.scalar() or 0) > 0

    def _where(self, **fields: t.Any):  # noqa: ANN201
        """Build a WHERE clause from keyword filters."""
        return and_(*(
            col(getattr(self.model, k)) == v
            for k, v in fields.items()
            if hasattr(self.model, k)
        ))


# PROJECT-SPECIFIC: instantiate one singleton per model at module bottom
# item_controller = Controller(model=Item)
```

> **Multi-tenancy note**: If the project has company/tenant scoping, extend `_where` to automatically append a `company_id` filter based on the current user, and accept a `current_user` parameter on every query method.

### Alembic Setup

```python
# migrations/env.py
import asyncio
import importlib
import pkgutil

import alembic_postgresql_enum  # noqa: F401 — side-effect import for enum support
from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine
from sqlmodel import SQLModel

from api.settings import settings


def _import_all_models() -> None:
    """Walk api.models and import every submodule so SQLModel.metadata is populated."""
    import api.models
    for _, name, _ in pkgutil.walk_packages(api.models.__path__, api.models.__name__ + "."):
        importlib.import_module(name)


_import_all_models()

engine = create_async_engine(settings.DB_URI.unicode_string(), echo=False, future=True, pool_pre_ping=True)
target_metadata = SQLModel.metadata


def _run_migrations(connection) -> None:  # noqa: ANN001
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def _run_async() -> None:
    async with engine.connect() as conn:
        await conn.run_sync(_run_migrations)


if context.is_offline_mode():
    msg = "Offline mode is not supported."
    raise RuntimeError(msg)

asyncio.run(_run_async())
```

```ini
# alembic.ini
[alembic]
script_location = migrations
file_template = %%(year)d%%(month).2d%%(day).2d%%(hour).2d%%(minute).2d_%%(slug)s
prepend_sys_path = .

[post_write_hooks]
hooks = ruff, ruff_format

ruff.type = exec
ruff.executable = ruff
ruff.options = check --fix REVISION_SCRIPT_FILENAME

ruff_format.type = exec
ruff_format.executable = ruff
ruff_format.options = format REVISION_SCRIPT_FILENAME
```

Rules:
- DB URI is never in `alembic.ini` — always injected from `settings` in `env.py`
- Offline mode is explicitly disabled
- Migration file naming: `YYYYMMDDhhmm_<slug>` (e.g. `202501151030_add_items_table`)
- New migration files are auto-linted and formatted by the post-write hooks
- `_import_all_models()` must run before `SQLModel.metadata` is read — ensures autogenerate sees all tables

---

## 9. Pydantic Schemas

### The Model Factory Pattern

Never manually duplicate field definitions between the SQLModel table model and the API schema. Use `model_factory` to derive Create, Update, and Response schemas from the single source of truth.

```python
# api/utils/model_factory.py
import typing as t

from pydantic import create_model
from sqlmodel import SQLModel


def model_factory(
    *,
    name: str,
    base: type,
    exclude: list[str] | None = None,
    include: list[str] | None = None,
    all_optionals: bool = False,
) -> type:
    """Derive a new Pydantic schema from a SQLModel table model.

    Args:
        name: Name for the generated class.
        base: The SQLModel table model to derive from.
        exclude: Fields to exclude from the generated schema.
        include: If provided, only include these fields.
        all_optionals: If True, make all fields optional (for PATCH schemas).

    Returns:
        A new Pydantic model class.
    """
    source_fields = base.model_fields
    if include:
        source_fields = {k: v for k, v in source_fields.items() if k in include}
    if exclude:
        source_fields = {k: v for k, v in source_fields.items() if k not in exclude}

    fields: dict[str, t.Any] = {}
    for field_name, field_info in source_fields.items():
        if all_optionals:
            fields[field_name] = (field_info.annotation | None, None)
        else:
            fields[field_name] = (field_info.annotation, field_info)

    return create_model(name, **fields, __base__=SQLModel)
```

```python
# api/factories.py — create one partial per model
from functools import partial
from api.utils.model_factory import model_factory
from api.models.item import Item

item_factory = partial(model_factory, base=Item)
```

```python
# api/schemas/item.py
from api.factories import item_factory
from api.models.base import API_EXCLUDE_FIELDS  # ["id", "created_at", "updated_at"]

ItemResponse = item_factory(name="ItemResponse")
ItemCreate = item_factory(name="ItemCreate", exclude=[*API_EXCLUDE_FIELDS, "company_id"])
ItemUpdate = item_factory(name="ItemUpdate", exclude=[*API_EXCLUDE_FIELDS, "company_id"], all_optionals=True)

# Extend the factory output for richer responses
class ItemResponseFull(ItemResponse):
    """Item response with nested related objects."""
    tags: list[TagResponse] = []
```

Standard schema set per resource:
- `FooResponse` — all fields, used for single-resource GET and write responses
- `FooCreate` — excludes `id`, `created_at`, `updated_at`, server-set FKs
- `FooUpdate` — same exclusions as Create, all fields optional (`all_optionals=True`)
- `FooResponseFull` — extends `FooResponse` with nested relationship fields (when needed)

---

## 10. Dependencies

### DB Session

```python
# api/dependencies/db.py
import typing as t
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from fastapi import Depends

from api.settings import settings

engine = create_async_engine(
    settings.DB_URI.unicode_string(),
    echo=settings.ENV == "local",
    future=True,
    pool_pre_ping=True,
    pool_size=16,
)
_session_factory = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)


@asynccontextmanager
async def get_context_db() -> t.AsyncGenerator[AsyncSession, None]:
    """Async context manager for DB sessions (use in non-endpoint code)."""
    async with _session_factory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def get_db() -> t.AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency for DB session injection."""
    async with get_context_db() as session:
        yield session


AsyncDBSession = t.Annotated[AsyncSession, Depends(get_db)]
```

Use `AsyncDBSession` as a type annotation directly in endpoint signatures — no explicit `Depends()` at the call site.

### The `Annotated[Type, Depends(...)]` Convention

All injectable dependencies must be expressed as `Annotated` type aliases. This keeps endpoint signatures clean and makes the dependency graph explicit in the type system.

```python
# Define once in the dependencies module:
AsyncDBSession = t.Annotated[AsyncSession, Depends(get_db)]
RequestUser = t.Annotated[User, Depends(get_current_user)]
RequireAdmin = t.Annotated[User, Depends(require_admin)]
QueryParams = t.Annotated[QueryParamsModel, Depends(get_query_params)]

# Use as plain type annotations in endpoints:
@router.get("/items")
async def list_items(*, db: AsyncDBSession, user: RequestUser, params: QueryParams) -> list[ItemResponse]:
    ...
```

### Authentication & Authorization

> **Ask the user** about the auth provider, token format, and role model before implementing authentication. The pattern below is a template — the specifics will vary.

The general pattern regardless of auth provider:

```python
# api/dependencies/auth.py
import typing as t
from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()


async def get_current_user(
    *,
    auth: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncDBSession,
) -> User:
    """Validate credentials and return the authenticated user.

    Raises:
        AuthError: If the token is invalid or expired.
    """
    # PROJECT-SPECIFIC: implement token validation here
    # Recommended practices:
    # - Hash tokens (SHA-256) before storing or comparing — never store raw tokens
    # - Cache validated sessions in the DB with a TTL to avoid hitting the auth
    #   provider on every request
    # - Raise AuthError (401) for invalid/expired tokens
    ...


RequestUser = t.Annotated[User, Depends(get_current_user)]
```

For role-based access control, build a dependency chain:

```python
async def require_admin(*, user: RequestUser) -> User:
    """Require admin role."""
    if user.role not in {Role.ADMIN, Role.SYSTEM}:
        raise PermissionDeniedError
    return user


RequireAdmin = t.Annotated[User, Depends(require_admin)]
# Similarly: RequireEditor, RequireViewer
```

Additional auth patterns from the reference implementations:
- **API key auth** (service-to-service): use `fastapi.security.APIKeyHeader`, hash keys before storage, support per-key IP allowlists
- **Per-tenant token auth** (webhooks): implement as a callable class with `__call__`, instantiate one per integration

### Pagination

```python
# api/dependencies/query_params.py
import typing as t
from fastapi import Depends, Query
from pydantic import BaseModel


class QueryParamsModel(BaseModel):
    """Pagination and ordering parameters."""
    limit: int | None = None
    page: int | None = None
    order_by: str = "id"


async def get_query_params(
    *,
    limit: t.Annotated[int | None, Query(ge=1)] = None,
    page: t.Annotated[int | None, Query(ge=1)] = None,
    order_by: t.Annotated[str, Query()] = "id",
) -> QueryParamsModel:
    """Parse and validate pagination query parameters."""
    if (limit is None) != (page is None):
        raise BadRequestError(detail="`limit` and `page` must be provided together.")
    return QueryParamsModel(limit=limit, page=page, order_by=order_by)


QueryParams = t.Annotated[QueryParamsModel, Depends(get_query_params)]
```

---

## 11. Testing

This section applies to FastAPI web services. For Lambda-only projects, apply judgment based on the project's complexity — at minimum, test the core business logic.

### Dependencies

Add to `[dependency-groups]` in `pyproject.toml`:

```toml
[dependency-groups]
test = [
    "gevent>=24.0",
    "pytest>=8.0",
    "pytest-asyncio>=0.24",
    "pytest-cov>=6.0",
    "pytest-env>=1.1",
    "pytest-instafail>=0.5",
    "pytest-lazy-fixtures>=1.1",
    "pytest-mock>=3.14",
    "pytest-socket>=0.7",
    "pytest-sugar>=1.0",
    "pytest-timeout>=2.3",
    "pytest-xdist>=3.6",
]
```

### Configuration

See the `[tool.pytest.ini_options]` block in [Section 3](#3-pyprojecttoml-reference). Key settings:

| Setting | Value | Why |
|---|---|---|
| `asyncio_mode = "auto"` | All async test functions run automatically | No `@pytest.mark.asyncio` boilerplate |
| `timeout = 3` | 3-second limit per test | Catches hanging tests early |
| `-n=auto` | Parallel workers via xdist | Faster test runs |
| `--dist=loadfile` | All tests in a file go to one worker | Prevents cross-worker DB conflicts |
| `--disable-socket` | Block all real network traffic | Tests must not call external APIs |
| `--allow-hosts=127.0.0.1,::1` | Only localhost traffic | LocalStack, test DB, etc. still work |
| `fail_under=95` | Fail if coverage drops below 95% | Non-negotiable threshold |

### DB Fixture Pattern

Use a nested transaction + rollback strategy so every test runs in isolation with zero state leakage:

```python
# tests/conftest.py
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

from api.settings import settings


@pytest.fixture(scope="session")
async def engine():
    """Create the test DB engine once per session."""
    _engine = create_async_engine(settings.DB_URI_TESTING.unicode_string(), ...)
    async with _engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)
    yield _engine
    async with _engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.drop_all)
    await _engine.dispose()


@pytest.fixture(autouse=True)
async def db_session(engine) -> AsyncGenerator[AsyncSession, None]:
    """Wrap every test in a transaction that is always rolled back."""
    async with engine.connect() as conn:
        await conn.begin()
        session = AsyncSession(bind=conn, expire_on_commit=False)
        yield session
        await session.close()
        await conn.rollback()
```

> **Ask the user** about the testing infrastructure (local DB vs test containers, external services to mock) before setting up `conftest.py`. The fixture structure above is a starting point — adapt it to the project's specific stack.

### pytest-env for Test Environment

Inject all required environment variables for tests via `pytest-env` so tests run without a `.env` file:

```toml
[tool.pytest.ini_options]
env = [
    "ENV=testing",
    "DB_URI=postgresql+asyncpg://test:test@localhost:5432/test_db",
    # PROJECT-SPECIFIC: add all required settings with test values
]
```

---

## 12. Pre-commit Hooks

Every project uses the same `.pre-commit-config.yaml`. The only project-specific part is the `no-commit-to-branch` list.

```yaml
# .pre-commit-config.yaml
exclude: '.git,.venv'
default_stages: [pre-commit]
default_install_hook_types:
  - pre-commit
  - post-checkout
  - post-merge
  - post-rewrite

repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: check-ast
      - id: check-executables-have-shebangs
      - id: check-shebang-scripts-are-executable
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-added-large-files
        args: [--maxkb=1000]
      - id: check-case-conflict
      - id: check-merge-conflict
      - id: check-symlinks
      - id: check-yaml
      - id: check-toml
      - id: check-json
      - id: pretty-format-json
        args: [--autofix]
      - id: debug-statements
      - id: check-docstring-first
      - id: no-commit-to-branch
        args: [--branch, main, --branch, dev, --branch, stage, --branch, prod]
        # PROJECT-SPECIFIC: adjust protected branch names
      - id: detect-aws-credentials
      - id: detect-private-key
      - id: mixed-line-ending
        args: [--fix=auto]

  - repo: local
    hooks:
      - id: uv-lock
        name: uv-lock
        language: system
        entry: uv lock
        pass_filenames: false
        always_run: true
        files: ^(uv\.lock|pyproject\.toml|uv\.toml)$

      - id: uv-sync
        name: uv-sync
        language: system
        entry: uv sync --locked --all-packages
        pass_filenames: false
        always_run: true
        stages: [post-checkout, post-merge, post-rewrite]
        files: ^(uv\.lock|pyproject\.toml|uv\.toml)$

      - id: ruff
        name: ruff
        language: system
        entry: uv run -- ruff check --config pyproject.toml
        pass_filenames: false
        always_run: true

      - id: ruff-format
        name: ruff-format
        language: system
        entry: uv run -- ruff format --config pyproject.toml
        pass_filenames: false
        always_run: true

      - id: bandit
        name: bandit
        language: system
        entry: uv run -- bandit -c pyproject.toml -r .
        pass_filenames: false
        always_run: true
```

All local hooks run on the **entire codebase** on every commit (`pass_filenames: false`, `always_run: true`). CI explicitly passes `--config pyproject.toml` so it uses the authoritative config, not the local `ruff.toml` override.

---

## 13. CI/CD

### PR Check Workflow

```yaml
# .github/workflows/pr_check.yml
name: PR Check

on:
  pull_request:
    types: [opened, ready_for_review, synchronize]
    branches: [main, dev, stage, prod]  # PROJECT-SPECIFIC
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  labeler:
    runs-on: ubuntu-22.04
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/labeler@v5
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}

  Ruff:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup_env
      - run: uv run --frozen --no-progress -- ruff check --output-format github --config pyproject.toml .

  Bandit:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup_env
      - run: uv run --frozen --no-progress -- bandit -c pyproject.toml -r .

  # PROJECT-SPECIFIC: add a Tests job for web services (see below)
```

For web services, add a `Tests` job that spins up service containers (Postgres, LocalStack, etc.) and runs `pytest`.

### Reusable Setup Action

```yaml
# .github/actions/setup_env/action.yml
name: Setup Python + uv
description: Install Python and uv, then sync the lockfile

runs:
  using: composite
  steps:
    - uses: actions/setup-python@v5
      with:
        python-version-file: pyproject.toml  # reads requires-python

    - uses: astral-sh/setup-uv@v5
      with:
        version: "x.x.x"                    # pin to current release: https://github.com/astral-sh/uv/releases
        enable-cache: true
        cache-dependency-glob: uv.lock

    - run: uv sync --all-extras --frozen
      shell: bash
```

### Auto-Labeler

```yaml
# .github/labeler.yml
documentation:
  - changed-files:
      - any-glob-to-any-file: "**/*.md"

ci_cd:
  - changed-files:
      - any-glob-to-any-file: ".github/**/*"

tests:
  - changed-files:
      - any-glob-to-any-file: "tests/**/*"

feature:
  - head-branch: ["^feature/.*"]

bug:
  - head-branch: ["^bug/.*", "^fix/.*"]

hotfix:
  - head-branch: ["^hotfix/.*"]

# PROJECT-SPECIFIC: add labels for source directories, migrations, etc.
```

### CODEOWNERS

```
# .github/CODEOWNERS
* @<owner>   # PROJECT-SPECIFIC: set the required reviewer
```

---

## 14. Container & Deployment

> **Ask the user** which deployment target applies before implementing this section.

### FastAPI Web Service — Podman

#### Multi-Stage Containerfile

Podman uses `Containerfile` by convention but also accepts `Dockerfile` — either name works.
Use `podman build` and `podman compose` in place of `docker build` and `docker compose`.
Podman is daemonless and rootless by default — no `sudo` required.

```dockerfile
# docker/app/Containerfile

# ── Stage 1: builder ──────────────────────────────────────────────────────────
FROM python:3.14-slim AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_NO_PROGRESS=1

COPY --from=ghcr.io/astral-sh/uv:x.x.x /uv /bin/uv
# ^ pin to the current release: https://github.com/astral-sh/uv/releases

WORKDIR /code
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# ── Stage 2: final ────────────────────────────────────────────────────────────
FROM python:3.14-slim AS final

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/.venv/bin:$PATH"

EXPOSE 8000

RUN groupadd --gid 1000 appuser && useradd --uid 1000 --gid 1000 --no-create-home appuser

WORKDIR /code
COPY --from=builder /code/.venv /.venv
COPY . .

USER appuser

HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8000/service/healthcheck/ || exit 1

CMD ["/code/docker/app/entrypoint.sh"]
```

#### `.containerignore`

Podman reads `.containerignore` (preferred) and falls back to `.dockerignore`.

```
.git
.github
.venv
.env
tests/
coverage/
ruff.toml
Makefile
compose.yml
**/__pycache__
**/*.pyc
**/.pytest_cache
**/.ruff_cache
```

#### Entrypoint

```bash
#!/bin/bash
# docker/app/entrypoint.sh

# Run migrations in the background so the app starts immediately
alembic upgrade head &

if [ "$ENV" = "local" ]; then
    uvicorn app:app --host 0.0.0.0 --port 8000 --reload
else
    # Use ddtrace-run if Datadog is configured, otherwise plain gunicorn
    exec gunicorn
fi
```

#### `gunicorn.conf.py`

```python
import multiprocessing

wsgi_app = "app:app"
bind = "0.0.0.0:8000"
workers = multiprocessing.cpu_count()
threads = workers * 2
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 1000
timeout = 30
keepalive = 2
preload = True
reload = False
errorlog = "-"
loglevel = "info"
accesslog = "-"
forwarded_allow_ips = "*"
```

#### `compose.yml` (local dev)

Podman Compose uses `compose.yml` (the modern Compose spec filename).
Run with `podman compose up -d`. Podman reads `compose.yml`, `docker-compose.yml`,
and `docker-compose.yaml` — `compose.yml` is preferred going forward.

```yaml
# compose.yml
services:
  app:
    build:
      context: .
      dockerfile: docker/app/Containerfile
    volumes:
      - .:/code:cached
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: appdb   # PROJECT-SPECIFIC
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  # PROJECT-SPECIFIC: add other services (localstack, opensearch, redis, etc.)

volumes:
  postgres_data:
```

> **Note**: `podman compose` requires `podman-compose` (`brew install podman-compose`) or
> Podman Desktop's built-in compose support. All `docker compose` commands map directly to
> `podman compose` — the syntax is identical.

### Lambda Function — AWS SAM

```yaml
# template.yml (excerpt)
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Runtime: python3.14
    Architectures: [x86_64]
    LoggingConfig:
      LogFormat: JSON          # structured logging

Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: my_function/
      Handler: main.handler
      MemorySize: 512          # PROJECT-SPECIFIC
      Timeout: 30              # PROJECT-SPECIFIC
      Metadata:
        BuildMethod: python-uv  # uv-aware SAM build
```

```toml
# samconfig.toml
version = 0.1

[default.build.parameters]
beta_features = true
parallel = true

[prod.deploy.parameters]
capabilities = ["CAPABILITY_IAM"]
region = "us-east-1"
stack_name = "project-name-prod"     # PROJECT-SPECIFIC
s3_bucket = "your-sam-deployments"   # PROJECT-SPECIFIC
parameter_overrides = "Environment=prod"
```

CI deploy workflow: use OIDC for AWS authentication (`id-token: write` permission, `aws-actions/configure-aws-credentials` with a role ARN from secrets — never long-lived access keys).

---

## 15. Environment Variables

### Rules (all projects)

- `.env.example` is **always committed** — it lists every required variable with empty or safe default values
- `.env` is **always in `.gitignore`** — never committed
- AWS credentials and all secrets go in `.env` locally; in production they come from IAM roles, Secrets Manager, or the deployment platform

### Web Services — pydantic-settings

```python
class Settings(BaseSettings):
    """All settings loaded from environment variables at startup."""
    # Missing required fields raise a ValidationError immediately on import
    ...

settings = Settings()
```

Use strong Pydantic types for validation: `PostgresDsn` for DB URIs, `AnyHttpUrl` for URLs, `list[str]` for comma-separated lists, `bool` for flags.

### Lambda Functions — dotenv + dataclass

```python
# utils/config.py
from dataclasses import dataclass
from os import environ

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Config:
    """Application configuration loaded from environment variables."""

    required_setting: str = environ.get("REQUIRED_SETTING", "")
    optional_setting: str = environ.get("OPTIONAL_SETTING", "default-value")
    aws_region: str = environ.get("AWS_REGION", "us-east-1")

    def __post_init__(self) -> None:
        """Validate that all required settings are present."""
        missing = [f for f in ["required_setting"] if not getattr(self, f)]
        if missing:
            msg = f"Missing required environment variables: {', '.join(missing)}"
            raise ValueError(msg)


config = Config()
```

---

## 16. Makefile

Every project has a `Makefile` with at minimum these targets. Use `##` comments for auto-generated help.

```makefile
UV := uv

.PHONY: help install fmt lint lint_ruff lint_bandit test check clean \
        pre_commit_install pre_commit_uninstall pre_commit_update pre_commit_run \
        uv_install uv_lock

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: uv_install pre_commit_install ## Bootstrap the project

fmt: ## Format code with ruff
	$(UV) run -- ruff format --config pyproject.toml .

lint_ruff: ## Run ruff linter
	$(UV) run -- ruff check --config pyproject.toml .

lint_bandit: ## Run bandit security scanner
	$(UV) run -- bandit -c pyproject.toml -r .

lint: lint_ruff lint_bandit ## Run all linters

test: ## Run the test suite
	$(UV) run -- pytest

check: fmt lint test pre_commit_run ## Run the full quality gate (fmt + lint + test + hooks)

clean: ## Remove build artifacts and caches
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -exec rm -rf {} +
	rm -rf .ruff_cache .pytest_cache coverage/ .coverage

pre_commit_install: ## Install pre-commit hooks
	$(UV) run -- pre-commit install

pre_commit_uninstall: ## Remove pre-commit hooks
	$(UV) run -- pre-commit uninstall

pre_commit_update: ## Update pre-commit hook versions
	$(UV) run -- pre-commit autoupdate

pre_commit_run: ## Run all pre-commit hooks on all files
	$(UV) run -- pre-commit run -a

uv_install: ## Install all dependencies
	$(UV) sync --all-packages

uv_lock: ## Regenerate the lockfile
	$(UV) lock

# PROJECT-SPECIFIC: add podman targets for web services
# build up down logs restart
#
# PROJECT-SPECIFIC: add migration targets for DB projects
# migration_create migration_upgrade migration_downgrade
```
