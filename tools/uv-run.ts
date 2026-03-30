import { tool } from "@opencode-ai/plugin";
import path from "path";

/**
 * Runs any command through `uv run --` inside the project's managed virtual
 * environment. Use this instead of constructing raw `uv run --` bash strings —
 * it ensures the correct Python interpreter and installed packages are always
 * used, regardless of where opencode is invoked from.
 *
 * Examples:
 *   uv_run({ command: ["pytest"] })
 *   uv_run({ command: ["ruff", "check", "--config", "pyproject.toml", "."] })
 *   uv_run({ command: ["alembic", "upgrade", "head"] })
 */
export default tool({
  description:
    "Run a command inside the project's uv-managed virtual environment via `uv run --`. " +
    "Use this for all Python tool invocations (pytest, ruff, bandit, alembic, etc.) " +
    "instead of raw bash to ensure the correct venv is always used.",
  args: {
    command: tool.schema
      .array(tool.schema.string())
      .min(1)
      .describe(
        "The command and its arguments to run, e.g. ['pytest', '-x'] or ['ruff', 'check', '.']"
      ),
    workdir: tool.schema
      .string()
      .optional()
      .describe(
        "Working directory to run the command in. Defaults to the project worktree root."
      ),
  },
  async execute(args, context) {
    const cwd = args.workdir ?? context.worktree;
    const [cmd, ...cmdArgs] = args.command;

    const result =
      await Bun.$`uv run -- ${cmd} ${cmdArgs} 2>&1`.cwd(cwd).nothrow().text();

    return result.trim() || "(no output)";
  },
});
