---
name: performance-analysis
description: >
  Deep performance investigation. Event loop blocking, N+1 queries, memory leaks, CPU profiling.
  Load when user reports slowness, high memory, or asks to profile/optimize.
---

# Performance Analysis Playbook

## Triage First

Determine bottleneck type before investigating:

| Symptom | Likely cause | Investigation |
|---------|-------------|---------------|
| Slow endpoint | DB query / N+1 / blocking I/O | EXPLAIN ANALYZE, async audit |
| High latency spikes | Event loop blocking | CPU profile, blocking call audit |
| Growing memory | Leak / unbounded cache | memory profiler, object tracking |
| High CPU | Compute in async handler | profiler, offload audit |

## Step 1: Measure Baseline

```bash
# Request timing
uv run -- python -c "import httpx, time; s=time.time(); httpx.get('http://localhost:8000/endpoint'); print(f'{(time.time()-s)*1000:.0f}ms')"

# DB query time (via MCP or logs)
# Check pg_stat_statements for slow queries
```

## Step 2: DB Performance

### N+1 Detection
- Query inside loop = N+1. Flag any:
  - Accessing relationship attrs in loop without `selectin`
  - `await db.refresh(obj, ["rel"])` inside loop
  - Multiple sequential queries that could be one JOIN

### EXPLAIN ANALYZE
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>;
```

Flag:
- `Seq Scan` on table >10k rows -> needs index
- `Nested Loop` with large outer set -> composite index or restructure
- Estimated vs actual rows diverge -> run `ANALYZE <table>`

### Index Strategy
- B-tree: equality, range, ORDER BY (most cases)
- GIN: JSONB `@>`, arrays, full-text
- BRIN: append-only time-series tables
- Partial: queries always filter on condition

## Step 3: Async Discipline

### Blocking I/O in Async (Critical)
Flag any of these in async functions:
- `time.sleep()` -> `asyncio.sleep()`
- `requests.get()` -> `httpx.AsyncClient`
- sync `open()` -> `aiofiles`
- CPU-bound work -> `asyncio.run_in_executor()`

### Event Loop Blocking Detection
```python
# Add temporarily to find blockers:
import asyncio
loop = asyncio.get_event_loop()
loop.slow_callback_duration = 0.1  # warn on >100ms callbacks
```

## Step 4: Memory

```bash
# Quick memory check
uv run -- python -c "import tracemalloc; tracemalloc.start(); ... ; print(tracemalloc.get_traced_memory())"
```

Flag:
- Module-level growing collections (unbounded caches)
- Resources not cleaned up (missing context managers)
- Large objects held in closures

## Step 5: Profiling

```bash
# cProfile for CPU
uv run -- python -m cProfile -o profile.out <script>
uv run -- python -c "import pstats; p=pstats.Stats('profile.out'); p.sort_stats('cumulative').print_stats(20)"
```

## Output Format

```
## Performance Analysis

### Bottleneck
<what is slow and measured baseline>

### Root Cause
<specific code causing the issue with file:line>

### Evidence
<measurements, EXPLAIN output, profile data>

### Fix
<specific changes needed>

### Expected Improvement
<estimated gain>
```

## Rules
- Measure before and after every change
- Never sacrifice clarity for performance
- Performance findings = Suggestions, never Blockers (unless deadlock/crash)
- Prefer readable O(n) over clever O(1) with unmaintainable code
