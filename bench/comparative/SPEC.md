
# Piper Cross-Language Benchmark Specification

## Purpose

This benchmark measures the runtime cost of:

1. direct function calls;
2. native pipe/threading syntax;
3. reusable function composition;

across:

- Nim + Piper
- Haskell
- Elixir
- F#
- OCaml

This is not a general-purpose language benchmark.

The benchmark specifically measures the execution of small unary function
pipelines.

---

## Workload

All languages implement exactly these transformations.

```text
double(x) = x * 2
addOne(x) = x + 1
square(x) = x * x
negate(x) = -x
```
