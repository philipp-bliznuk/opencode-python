---
name: performance-analysis
description: Deep performance investigation playbook. Covers Python CPU and memory profiling, async event loop analysis, FastAPI-specific diagnostics, database query analysis, and frontend bundle analysis. Load this when the user reports slowness, high memory usage, timeouts, or explicitly asks to profile, benchmark, or optimise.
license: MIT
compatibility: opencode
---

# Skill: Performance Analysis

## Rule zero — measure first, always

You cannot know if a change helps without measuring before and after.
Never make a "performance improvement" without a baseline. Guessing is worse
than doing nothing — you might optimise the wrong thing.

```
Workflow:
1. Measure current state → record the baseline (wall time, memory peak, query count)
2. Form one hypothesis about the bottleneck
3. Make one change
4. Measure again under identical conditions
5. Accept only if measurably better AND not less readable
6. Document what was measured and what changed
```

---

## Step 1 — Identify the bottleneck category

Before reaching for a profiler, determine which category the problem falls into:

| Symptom | Likely category |
|---|---|
| High CPU, slow under load | CPU-bound code or blocking the event loop |
| Slow even with low CPU | I/O-bound: DB, network, disk |
| Memory grows over time | Memory leak: unclosed resources, reference cycles, unbounded cache |
| Slow first request, fast subsequent | Cold start: module imports, connection pool setup |
| Latency spikes at specific intervals | GC pressure, background task contention |
| Slow only for specific queries | DB query plan issue → delegate to `@db` |

---

## Step 2 — Python CPU profiling

### `py-spy` (no code changes, works on running processes)

```bash
# Find the process ID first
uv run -- python -c "import os; print(os.getpid())"
# or for a running uvicorn:
pgrep -a uvicorn

# Live top-like view (Ctrl+C to stop)
py-spy top --pid <pid>

# Record a flamegraph (let it run during the slow operation)
py-spy record -o profile.svg --pid <pid> --duration 30
open profile.svg
```

Install if needed: `uv add --dev py-spy`

### `cProfile` (built-in, good for scripts and tests)

```bash
# Profile a specific test
uv run -- python -m cProfile -s cumtime -m pytest tests/path/to/test.py -v 2>&1 | head -40

# Profile a script
uv run -- python -m cProfile -s cumtime my_script.py
```

### Reading a flamegraph / cProfile output

- Wide boxes at the top = hotspots (most time spent)
- Look for unexpected library code taking time (JSON serialisation, Pydantic validation, SQLAlchemy ORM overhead)
- In cProfile: sort by `cumtime` (total time including callees) to find the root; sort by `tottime` (self time only) to find the leaf

---

## Step 3 — Python memory profiling

### `memray` (recommended — detailed, low overhead)

```bash
uv add --dev memray

# Profile a script
uv run -- memray run -o output.bin my_script.py

# Profile a test
uv run -- memray run -o output.bin -m pytest tests/path/to/test.py

# Generate a flamegraph
uv run -- memray flamegraph output.bin
open memray-flamegraph-output.html

# Check for leaks (memory not freed at program exit)
uv run -- memray run --leak-check -o output.bin my_script.py
```

### `tracemalloc` (built-in, good for targeted memory delta measurement)

```python
import tracemalloc

tracemalloc.start()

# ... run the suspect code ...

snapshot = tracemalloc.take_snapshot()
top_stats = snapshot.statistics('lineno')
for stat in top_stats[:10]:
    print(stat)
```

### Common memory leak patterns in Python

- **Unclosed resources**: HTTP clients, file handles, DB sessions not closed. Always use context managers.
- **Module-level singletons growing unboundedly**: caches without a max size (`dict` that only ever grows).
- **Reference cycles with `__del__`**: Python's GC handles most cycles, but `__del__` can prevent collection.
- **asyncio tasks not awaited**: fire-and-forget tasks that accumulate in the event loop.
- **SQLAlchemy `expire_on_commit=False` + large objects in session**: objects held in the session cache longer than expected.

---

## Step 4 — Async event loop analysis

### Detect blocking calls

The event loop is single-threaded. Any synchronous blocking call freezes all
concurrent requests for its duration.

Enable debug mode to log coroutines that take longer than 100ms:

```python
# In your app startup (local/dev only — verbose in production)
import asyncio
asyncio.get_event_loop().set_debug(True)
asyncio.get_event_loop().slow_callback_duration = 0.1  # 100ms threshold
```

### Symptoms of event loop blocking

- p99 latency much higher than p50 (blocking stalls other requests)
- `py-spy top` shows time in `select` or `epoll` with low CPU (waiting)
- `py-spy top` shows time in synchronous library code (`json.loads`, `re.match` on large inputs, etc.)

### CPU-bound work in async handlers

If you find CPU-bound code (compression, image processing, heavy computation)
running in an async endpoint, offload it:

```python
import asyncio
from concurrent.futures import ProcessPoolExecutor

_executor = ProcessPoolExecutor()

async def process_large_file(data: bytes) -> bytes:
    """Offload CPU-bound compression to a process pool."""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(_executor, compress_data, data)
```

Use `ProcessPoolExecutor` for CPU-bound, `ThreadPoolExecutor` for blocking I/O
that cannot be made async (legacy sync libraries).

---

## Step 5 — FastAPI-specific diagnostics

### Measure endpoint response time

Add a temporary timing decorator to isolate which part of a slow endpoint is slow:

```python
import time
import logging

logger = logging.getLogger(__name__)

@router.get("/slow-endpoint")
async def slow_endpoint(*, db: AsyncDBSession) -> Response:
    t0 = time.perf_counter()

    result = await some_query(db=db)
    logger.info("query: %.3fs", time.perf_counter() - t0)

    processed = await process(result)
    logger.info("process: %.3fs", time.perf_counter() - t0)

    return processed
```

### Connection pool exhaustion check

Your standard pool is `pool_size=16` (from `AGENTS.md`). If requests queue behind
DB calls, the pool may be exhausted:

```python
# In a diagnostic endpoint or script:
from api.dependencies.db import engine

status = engine.pool.status()
print(status)
# Output: "Pool size: 16  Connections in pool: 4 Current Overflow: 0 Current Checked out connections: 12"
# "Checked out: 12" approaching 16 → pool near exhaustion
```

Signs of pool exhaustion in logs: `QueuePool limit of size 16 overflow 0 reached`.

### Count queries per request

Enable SQLAlchemy echo temporarily to log every query:

```python
# In settings.py — local only
engine = create_async_engine(
    ...,
    echo=settings.ENV == "local",   # already set — just check the log output
)
```

Count the number of `SELECT` statements for a single API call. More than 3–5
for a simple read endpoint usually indicates N+1 or missing `selectin` loading.

---

## Step 6 — Database query analysis

For detailed DB analysis, delegate to `@db` with `EXPLAIN (ANALYZE, BUFFERS)`.

Quick check via the postgres MCP (if running):

```sql
-- Find the top slow queries
SELECT query, calls, round(mean_exec_time::numeric, 2) AS mean_ms
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

Key patterns to look for before calling `@db`:
- Same query called many times in one request cycle (N+1)
- Queries with `mean_ms > 50` that run frequently (`calls > 1000`)
- Sequential scans on tables with > 10k rows

---

## Step 7 — Frontend performance (bun / Vite)

### Bundle size analysis

```bash
cd frontend

# Vite bundle analysis (generates an interactive HTML report)
bun run build -- --analyze
# or if not configured in vite.config.ts:
bun add -d rollup-plugin-visualizer
# (add to vite.config.ts plugins, then build)

open dist/stats.html
```

**What to look for:**
- Large vendor chunks that are only used on one route → code-split them
- Same library included twice (CommonJS + ESM versions) → check imports
- `moment.js` or similar large date libraries → replace with `date-fns` or native `Intl`

### Lighthouse audit

```bash
# Requires: bun run dev (frontend must be running)
bunx lighthouse http://localhost:5173 --output html --output-path ./lighthouse.html
open lighthouse.html
```

Focus on: First Contentful Paint, Total Blocking Time, Largest Contentful Paint.

---

## Step 8 — Benchmarking methodology

Never trust a single measurement. Variance from GC, OS scheduling, and cache
warmup can make a slow code path look fast.

```
Minimum valid benchmark:
1. Warm up: run the operation 3 times (discarded) to fill caches
2. Measure: run 10–100 times, record each
3. Report: median and p95 (not average — outliers skew averages)
4. Baseline vs change: run both in the same session on the same machine
5. Statistical significance: the change should be > 2x the standard deviation
   before claiming improvement
```

Simple Python benchmark scaffold:

```python
import statistics
import time

def benchmark(fn, n: int = 50) -> None:
    """Run fn n times and report median and p95."""
    # Warmup
    for _ in range(3):
        fn()
    # Measure
    times = []
    for _ in range(n):
        t0 = time.perf_counter()
        fn()
        times.append(time.perf_counter() - t0)
    print(f"median: {statistics.median(times)*1000:.2f}ms")
    print(f"p95:    {sorted(times)[int(n*0.95)]*1000:.2f}ms")
    print(f"stdev:  {statistics.stdev(times)*1000:.2f}ms")
```

---

## Step 9 — When to stop

If the change makes code less readable, undo it. Performance is never worth a
readability trade-off unless there is a **proven, measured, production impact**
with a clear user-visible effect (latency SLA breach, OOM kill, sustained high
CPU cost).

The order of priority is always:
1. **Correctness** — code must be right
2. **Readability** — code must be maintainable
3. **Standards compliance** — AGENTS.md rules are non-negotiable
4. **Performance** — optimise only what is measured and proven to matter
