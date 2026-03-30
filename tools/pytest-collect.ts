import { tool } from "@opencode-ai/plugin";

/**
 * Runs `pytest --collect-only` and returns the list of collected test node IDs
 * without actually executing any tests. Use this after writing new test files
 * to verify they are discovered correctly before running the full suite.
 *
 * Also surfaces collection errors (syntax errors, import failures) that would
 * silently prevent tests from running.
 *
 * Examples:
 *   pytest_collect({})                              → collect all tests
 *   pytest_collect({ path: "tests/routers/" })      → collect a subdirectory
 *   pytest_collect({ path: "tests/test_items.py" }) → collect one file
 */
export default tool({
  description:
    "Collect pytest test node IDs without running them. " +
    "Use this after writing new tests to confirm they are discovered correctly " +
    "and to surface any collection errors (import failures, syntax errors) " +
    "before running the full suite.",
  args: {
    path: tool.schema
      .string()
      .optional()
      .describe(
        "Path to collect from — a file, directory, or test node ID. " +
          "Defaults to the configured testpaths in pyproject.toml."
      ),
    filter: tool.schema
      .string()
      .optional()
      .describe(
        "Optional -k filter expression to narrow collection, e.g. 'test_create or test_update'."
      ),
  },
  async execute(args, context) {
    const pathArg = args.path ? [args.path] : [];
    const filterArg = args.filter ? ["-k", args.filter] : [];

    const result =
      await Bun.$`uv run -- pytest --collect-only -q ${pathArg} ${filterArg} 2>&1`
        .cwd(context.worktree)
        .nothrow()
        .text();

    const output = result.trim();

    // Detect collection errors
    if (output.includes("ERROR collecting") || output.includes("ImportError")) {
      return `Collection errors detected:\n\n${output}`;
    }

    // Parse out test node IDs (lines that don't start with whitespace and
    // contain "::" — pytest's node ID format)
    const lines = output.split("\n");
    const nodeIds = lines.filter(
      (line) => line.includes("::") && !line.startsWith(" ")
    );

    if (nodeIds.length === 0) {
      return `No tests collected.\n\nFull output:\n${output}`;
    }

    const summary = lines
      .filter(
        (line) =>
          line.startsWith("=") ||
          line.match(/^\d+ (test|error|warning)/) !== null
      )
      .join("\n");

    return (
      `${nodeIds.length} test(s) collected:\n\n${nodeIds.join("\n")}` +
      (summary ? `\n\n${summary}` : "")
    );
  },
});
