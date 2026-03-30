import { tool } from "@opencode-ai/plugin";

/**
 * Runs `ruff check` and returns structured JSON output — an array of violation
 * objects with file, line, column, rule code, and message. More useful than
 * parsing colourised terminal text when an agent needs to programmatically
 * verify its own output or report specific violations.
 *
 * Returns an empty array if no violations are found (clean output).
 *
 * Examples:
 *   ruff_check({ paths: ["."] })                        → check everything
 *   ruff_check({ paths: ["api/routers/items.py"] })     → check one file
 *   ruff_check({ paths: ["api/"], fix: true })          → check and auto-fix
 */
export default tool({
  description:
    "Run ruff lint check and return structured JSON violations. " +
    "Use this after writing or modifying Python files to programmatically verify " +
    "compliance with project standards. Returns an array of violation objects " +
    "(empty array = clean). Prefer this over raw bash ruff invocations.",
  args: {
    paths: tool.schema
      .array(tool.schema.string())
      .min(1)
      .describe(
        "File paths or directories to check, e.g. ['.'] or ['api/routers/items.py']"
      ),
    fix: tool.schema
      .boolean()
      .optional()
      .default(false)
      .describe("Whether to apply auto-fixes. Defaults to false (check only)."),
  },
  async execute(args, context) {
    const fixFlag = args.fix ? ["--fix"] : [];
    const paths = args.paths;

    const result =
      await Bun.$`uv run -- ruff check --config pyproject.toml --output-format json ${fixFlag} ${paths} 2>/dev/null`
        .cwd(context.worktree)
        .nothrow()
        .text();

    let violations: unknown[] = [];
    try {
      violations = JSON.parse(result.trim() || "[]");
    } catch {
      // ruff errored before producing JSON (e.g. config not found)
      return `ruff failed to produce JSON output:\n${result.trim()}`;
    }

    if (!Array.isArray(violations) || violations.length === 0) {
      return "No violations found.";
    }

    // Return a concise summary alongside the raw data
    const summary = (violations as Array<Record<string, unknown>>)
      .map((v) => {
        const loc = v.location as { row: number; column: number } | undefined;
        return `${v.filename}:${loc?.row ?? "?"}:${loc?.column ?? "?"} [${v.code}] ${v.message}`;
      })
      .join("\n");

    return `${violations.length} violation(s):\n\n${summary}\n\n---\nRaw JSON:\n${JSON.stringify(violations, null, 2)}`;
  },
});
