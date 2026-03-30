---
name: new-lambda-project
description: Complete step-by-step scaffold for a new AWS Lambda project using SAM and uv workspaces. Covers workspace pyproject.toml, per-function structure, template.yml, samconfig.toml, pre-commit, and OIDC-based CI/CD. Load this when the user asks to create, bootstrap, or scaffold a new Lambda, SAM, or serverless Python project.
license: MIT
compatibility: opencode
---

# Skill: New Lambda/SAM Project Scaffold

## Before you start — ask the user

Do not begin writing files until you have answers to all of these:

1. **Project name** — used for the directory, SAM stack name, and S3 prefix
2. **Function names** — list of Lambda functions (e.g. `gateway`, `worker`). Each gets its own subdirectory.
3. **AWS region** — deployment region (default: `us-east-1`)
4. **AWS profile** — local named profile for `sam deploy` (default: `default`)
5. **SAM S3 bucket** — existing S3 bucket for SAM deployment artifacts
6. **Protected branches** — which branch names to block from direct commits? (default: `main`)
7. **GitHub owner/team** — for `CODEOWNERS` (e.g. `@acme/backend`)

---

## Step 1 — Initialise the workspace

```bash
mkdir <project-name> && cd <project-name>
uv init --no-package
echo "3.14" > .python-version
```

Edit `pyproject.toml` to configure the uv workspace. Each function is a workspace member:

```toml
[tool.uv.workspace]
members = ["<function-name-1>", "<function-name-2>"]
```

---

## Step 2 — Per-function directories

For each function, create a subdirectory with its own `pyproject.toml` and `main.py`:

### `<function-name>/pyproject.toml`
```toml
[project]
name = "<function-name>"
version = "0.1.0"
requires-python = ">=3.14"
dependencies = [
    # Add function-specific runtime deps here
    # e.g. "boto3", "httpx", "pydantic"
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

### `<function-name>/main.py`
```python
import logging
import typing as t


logger = logging.getLogger(__name__)


def handler(event: dict[str, t.Any], context: t.Any) -> dict[str, t.Any]:
    """Lambda function entry point.

    Args:
        event: The Lambda event payload.
        context: The Lambda runtime context.

    Returns:
        The response payload.
    """
    logger.info("Event received", extra={"event": event})
    return {"statusCode": 200, "body": "ok"}
```

---

## Step 3 — Root `pyproject.toml` (workspace tooling)

The workspace root `pyproject.toml` holds dev tooling only — no runtime deps:

```toml
[project]
name = "<project-name>"
version = "0.1.0"
requires-python = ">=3.14"
dependencies = []

[tool.uv]
package = false

[tool.uv.workspace]
members = ["<function-name-1>", "<function-name-2>"]

[dependency-groups]
dev = [
    "bandit[toml]>=1.9",
    "icecream>=2.1",
    "pre-commit>=4.0",
    "ruff>=0.15",
]
```

Then add the full ruff, bandit sections from `AGENTS.md` Section 3. Key substitutions:
- `src = ["<function-name-1>", "<function-name-2>"]`
- `known-first-party = ["<function-name-1>", "<function-name-2>"]`
- `targets = ["<function-name-1>", "<function-name-2>"]` in `[tool.bandit]`
- No pytest/coverage blocks — Lambda projects test at the function level if at all

---

## Step 4 — `ruff.toml` local override

```toml
# ruff.toml — local/IDE override only. CI uses --config pyproject.toml.
extend = "./pyproject.toml"

[lint]
unfixable = [
    "F401",
    "T20",
]
```

---

## Step 5 — `template.yml`

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Transform: AWS::Serverless-2016-10-31
Description: <project-name>

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
    Default: dev

Globals:
  Function:
    Runtime: python3.14
    Architectures: [x86_64]
    Environment:
      Variables:
        ENV: !Ref Environment
    LoggingConfig:
      LogFormat: JSON
      ApplicationLogLevel: INFO
      SystemLogLevel: WARN

Resources:
  # Repeat this block per function
  <FunctionName>Function:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub "<project-name>-<function-name>-${Environment}"
      CodeUri: <function-name>/
      Handler: main.handler
      MemorySize: 256       # adjust per function
      Timeout: 30           # adjust per function
      # ReservedConcurrentExecutions: 1  # uncomment if single-execution required
      Policies:
        - AWSLambdaBasicExecutionRole
        # Add additional policies here — always least privilege
      Metadata:
        BuildMethod: python-uv

Outputs:
  <FunctionName>FunctionArn:
    Value: !GetAtt <FunctionName>Function.Arn
```

---

## Step 6 — `samconfig.toml`

```toml
version = 0.1

[default.build.parameters]
beta_features = true
parallel = true

[default.validate.parameters]
lint = true

[dev.deploy.parameters]
capabilities = ["CAPABILITY_IAM"]
region = "<aws-region>"
stack_name = "<project-name>-dev"
s3_bucket = "<sam-s3-bucket>"
s3_prefix = "<project-name>"
parameter_overrides = "Environment=dev"
confirm_changeset = false
fail_on_empty_changeset = false

[prod.deploy.parameters]
capabilities = ["CAPABILITY_IAM"]
region = "<aws-region>"
stack_name = "<project-name>-prod"
s3_bucket = "<sam-s3-bucket>"
s3_prefix = "<project-name>"
parameter_overrides = "Environment=prod"
confirm_changeset = true
fail_on_empty_changeset = false
```

---

## Step 7 — `.env.example`

```bash
# Application
ENV=local
AWS_REGION=<aws-region>
AWS_PROFILE=<aws-profile>

# Add all required settings here — one line per variable
# AWS credentials are NOT stored here — use IAM roles or local ~/.aws/credentials
```

---

## Step 8 — `.gitignore`

```gitignore
# Python
.venv/
__pycache__/
*.pyc
*.pyo
*.pyd
*.egg-info/
dist/
build/
.Python

# Environment
.env

# Tools
.ruff_cache/
.pytest_cache/
.mypy_cache/
coverage/
.coverage

# SAM
.aws-sam/
samconfig.toml.bak

# macOS
.DS_Store

# IDE
.idea/
.vscode/
*.swp
```

---

## Step 9 — `Makefile`

```makefile
UV  := uv
SAM := sam

.PHONY: help install fmt lint lint_ruff lint_bandit check clean \
        pre_commit_install pre_commit_uninstall pre_commit_update pre_commit_run \
        uv_install uv_lock sam_build sam_validate sam_deploy_dev sam_deploy_prod

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}'

install: uv_install pre_commit_install ## Bootstrap the project

fmt: ## Format code with ruff
	$(UV) run -- ruff format --config pyproject.toml .

lint_ruff: ## Run ruff linter
	$(UV) run -- ruff check --config pyproject.toml .

lint_bandit: ## Run bandit security scanner
	$(UV) run -- bandit -c pyproject.toml -r .

lint: lint_ruff lint_bandit ## Run all linters

check: fmt lint pre_commit_run ## Full quality gate (no tests — add if applicable)

clean: ## Remove build artifacts and caches
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -exec rm -rf {} +
	rm -rf .ruff_cache .pytest_cache .aws-sam/

pre_commit_install: ## Install pre-commit hooks
	$(UV) run -- pre-commit install --install-hooks

pre_commit_uninstall: ## Remove pre-commit hooks
	$(UV) run -- pre-commit uninstall

pre_commit_update: ## Update hook versions
	$(UV) run -- pre-commit autoupdate

pre_commit_run: ## Run all hooks on all files
	$(UV) run -- pre-commit run -a

uv_install: ## Install all dependencies
	$(UV) sync --all-packages

uv_lock: ## Regenerate lockfile
	$(UV) lock

sam_build: ## Build SAM application
	$(SAM) build --beta-features --parallel

sam_validate: ## Validate SAM template
	$(SAM) validate --lint

sam_deploy_dev: sam_build ## Deploy to dev environment
	$(SAM) deploy --config-env dev

sam_deploy_prod: sam_build ## Deploy to prod environment (confirm required)
	$(SAM) deploy --config-env prod
```

---

## Step 10 — `.pre-commit-config.yaml`

Use the full canonical version from `AGENTS.md` Section 12. Substitute protected branch names in `no-commit-to-branch` with the user's answer.

---

## Step 11 — GitHub Actions

### `.github/CODEOWNERS`
```
* <github-owner-from-user-answer>
```

### `.github/labeler.yml`
Use the canonical version from `AGENTS.md` Section 13. Add function-specific labels:
```yaml
# One entry per Lambda function
<function-name>:
  - changed-files:
      - any-glob-to-any-file: "<function-name>/**/*"
sam:
  - changed-files:
      - any-glob-to-any-file: "template.yml"
      - any-glob-to-any-file: "samconfig.toml"
```

### `.github/actions/setup_env/action.yml`
Use the canonical version from `AGENTS.md` Section 13 verbatim.

### `.github/workflows/pr_check.yml`
Use the canonical version from `AGENTS.md` Section 13. Add a `SAM-Validate` job:
```yaml
SAM-Validate:
  runs-on: ubuntu-22.04
  steps:
    - uses: actions/checkout@v4
    - uses: ./.github/actions/setup_env
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
        aws-region: <aws-region>
    - run: sam build --beta-features --parallel
    - run: sam validate --lint
```

### `.github/workflows/deploy.yml`
```yaml
name: Deploy

on:
  push:
    branches: [main]   # adjust to your protected branch
  workflow_dispatch:
    inputs:
      environment:
        description: Target environment
        required: true
        default: dev
        type: choice
        options: [dev, prod]

permissions:
  id-token: write   # required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-22.04
    environment: ${{ github.event.inputs.environment || 'dev' }}
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup_env
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: <aws-region>
      - run: sam build --beta-features --parallel
      - run: sam deploy --config-env ${{ github.event.inputs.environment || 'dev' }} --no-confirm-changeset
```

> AWS authentication uses OIDC — never long-lived access keys. `AWS_DEPLOY_ROLE_ARN` is a GitHub Actions secret containing the IAM role ARN that trusts the GitHub OIDC provider.

---

## Step 12 — Final bootstrap

```bash
uv lock
uv sync --all-packages
uv run -- pre-commit install --install-hooks
make fmt
make lint
make sam_validate
```

Confirm all output is clean before handing back to the user.

---

## Step 13 — CLAUDE.md

Create `CLAUDE.md` at the project root documenting:
- Python version and number of functions
- Key `make` targets
- AWS profile and region for local testing
- How to invoke a function locally: `sam local invoke <FunctionName>Function -e events/test.json`
- Any non-obvious architectural decisions
