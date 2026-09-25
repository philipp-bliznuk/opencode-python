---
name: performance-analysis
description: Performance investigation — event loop blocking, N+1, memory leaks, CPU profiling. Load on slowness, high memory, or profile/optimize requests.
---

## Triage
| Symptom | Cause | Check |
|---|---|---|
| Slow endpoint | N+1 / blocking I/O | EXPLAIN ANALYZE, async audit |
| Latency spikes | Event loop blocked | CPU profile |
| Growing memory | Leak / unbounded cache | tracemalloc |
| High CPU | Compute in handler | cProfile, offload |

## Measure first
Time request with `httpx`; `pg_stat_statements` for slow queries. Record baseline.

## DB
- N+1: relationship access in loop w/o `selectin`; `db.refresh(obj, ["rel"])` in loop; sequential queries → JOIN.
- `EXPLAIN (ANALYZE, BUFFERS) <query>` — flag `Seq Scan` >10k rows, `Nested Loop` big outer, estimate≠actual → `ANALYZE <table>`.
- Index: B-tree default · GIN for JSONB/arrays/fulltext · BRIN append-only time-series · partial for constant filters.

## Async
`time.sleep` → `asyncio.sleep` · `requests` → `httpx.AsyncClient` · `open()` → `aiofiles` · CPU → `run_in_executor`.
Find blockers: `loop.slow_callback_duration = 0.1`.

## Memory
`tracemalloc`; flag module-level growing collections, missing context managers, big closures.

## CPU
`uv run -- python -m cProfile -o profile.out <script>` → `pstats` sort `cumulative`.

## Output
```
Bottleneck: what + baseline
Root cause: `file:line`
Evidence: measurements / EXPLAIN / profile
Fix + expected gain
```
Measure before/after. Perf findings = Suggestions unless crash/deadlock. Readable O(n) > clever O(1).
