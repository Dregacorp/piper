import std/[algorithm, monotimes, times, volatile]
import piper

const
  Iterations = 3_000_000
  Repeats = 9
  InputCount = 1024

var blackHole {.global.}: int

# ============================================================
# Noinline functions
# ============================================================

proc doubleNoInline(x: int): int {.noinline.} =
  x * 2


proc addOneNoInline(x: int): int {.noinline.} =
  x + 1


proc squareNoInline(x: int): int {.noinline.} =
  x * x


proc negateNoInline(x: int): int {.noinline.} =
  -x

# ============================================================
# Closure values
# ============================================================

let doubleClosure: Fn[int, int] =
  proc(x: int): int =
    doubleNoInline(x)


let addOneClosure: Fn[int, int] =
  proc(x: int): int =
    addOneNoInline(x)


let squareClosure: Fn[int, int] =
  proc(x: int): int =
    squareNoInline(x)


let negateClosure: Fn[int, int] =
  proc(x: int): int =
    negateNoInline(x)

# ============================================================
# Current piper composition
# ============================================================

let current2 =
  doubleClosure >>>
  addOneClosure


let current3 =
  doubleClosure >>>
  addOneClosure >>>
  squareClosure


let current4 =
  doubleClosure >>>
  addOneClosure >>>
  squareClosure >>>
  negateClosure

# ============================================================
# Experimental flat composers
#
# These create ONE closure containing the entire pipeline.
#
# They are deliberately separate from piper's public API for now.
# ============================================================

proc flatCompose2[A, B, C](
    f: Fn[A, B],
    g: Fn[B, C]
  ): Fn[A, C] =
  result = proc(x: A): C =
    g(f(x))


proc flatCompose3[A, B, C, D](
    f: Fn[A, B],
    g: Fn[B, C],
    h: Fn[C, D]
  ): Fn[A, D] =
  result = proc(x: A): D =
    h(g(f(x)))


proc flatCompose4[A, B, C, D, E](
    f: Fn[A, B],
    g: Fn[B, C],
    h: Fn[C, D],
    i: Fn[D, E]
  ): Fn[A, E] =
  result = proc(x: A): E =
    i(h(g(f(x))))

# Build the flat pipelines once.

let flat2 =
  flatCompose2(
    doubleClosure,
    addOneClosure
  )


let flat3 =
  flatCompose3(
    doubleClosure,
    addOneClosure,
    squareClosure
  )


let flat4 =
  flatCompose4(
    doubleClosure,
    addOneClosure,
    squareClosure,
    negateClosure
  )

# ============================================================
# Direct noinline baselines
# ============================================================

proc benchDirectNoInline2(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total +=
      addOneNoInline(
        doubleNoInline(x)
      )

  total


proc benchDirectNoInline3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total +=
      squareNoInline(
        addOneNoInline(
          doubleNoInline(x)
        )
      )

  total


proc benchDirectNoInline4(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total +=
      negateNoInline(
        squareNoInline(
          addOneNoInline(
            doubleNoInline(x)
          )
        )
      )

  total

# ============================================================
# Direct closure baselines
# ============================================================

proc benchDirectClosure2(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total +=
      addOneClosure(
        doubleClosure(x)
      )

  total


proc benchDirectClosure3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total +=
      squareClosure(
        addOneClosure(
          doubleClosure(x)
        )
      )

  total


proc benchDirectClosure4(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total +=
      negateClosure(
        squareClosure(
          addOneClosure(
            doubleClosure(x)
          )
        )
      )

  total

# ============================================================
# Current >>> implementation
# ============================================================

proc benchCurrent2(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total += current2(x)

  total


proc benchCurrent3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total += current3(x)

  total


proc benchCurrent4(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total += current4(x)

  total

# ============================================================
# Specialized flat composition
# ============================================================

proc benchFlat2(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total += flat2(x)

  total


proc benchFlat3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total += flat3(x)

  total


proc benchFlat4(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total += flat4(x)

  total

# ============================================================
# Construction benchmarks
# ============================================================

proc benchBuildCurrent3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    let pipeline =
      doubleClosure >>>
      addOneClosure >>>
      squareClosure

    total += pipeline(x)

  total


proc benchBuildFlat3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    let pipeline =
      flatCompose3(
        doubleClosure,
        addOneClosure,
        squareClosure
      )

    total += pipeline(x)

  total

# ============================================================
# Benchmark harness
# ============================================================

template runBenchmark(
    name: string,
    benchmark: untyped,
    inputs: untyped
  ) =
  discard benchmark(inputs)

  var samples: array[Repeats, int64]

  for runIndex in 0 ..< Repeats:
    let start = getMonoTime()

    let result = benchmark(inputs)

    let finish = getMonoTime()

    samples[runIndex] =
      (finish - start).inNanoseconds

    volatileStore(
      addr blackHole,
      result
    )

  samples.sort()

  let medianNs =
    samples[Repeats div 2]

  let nsPerOperation =
    medianNs.float / Iterations.float

  echo name
  echo "  median: ", medianNs, " ns"
  echo "  ns/op:  ", nsPerOperation
  echo ""

# ============================================================
# Main
# ============================================================

proc main() =
  var inputs: array[InputCount, int]

  var state = 0x13579B

  for i in 0 ..< InputCount:
    state = state xor (state shl 13)
    state = state xor (state shr 17)
    state = state xor (state shl 5)

    inputs[i] =
      (state mod 10000) + i

  # ----------------------------------------------------------
  # Correctness
  # ----------------------------------------------------------

  const TestValue = 7

  let expected2 =
    addOneNoInline(
      doubleNoInline(TestValue)
    )

  let expected3 =
    squareNoInline(
      addOneNoInline(
        doubleNoInline(TestValue)
      )
    )

  let expected4 =
    negateNoInline(
      squareNoInline(
        addOneNoInline(
          doubleNoInline(TestValue)
        )
      )
    )

  if expected2 != 15:
    raise newException(
      AssertionDefect,
      "unexpected 2-stage result: " & $expected2
    )

  if expected3 != 225:
    raise newException(
      AssertionDefect,
      "unexpected 3-stage result: " & $expected3
    )

  if expected4 != -225:
    raise newException(
      AssertionDefect,
      "unexpected 4-stage result: " & $expected4
    )

  if current2(TestValue) != expected2:
    raise newException(
      AssertionDefect,
      "current >>> 2-stage result is incorrect"
    )

  if current3(TestValue) != expected3:
    raise newException(
      AssertionDefect,
      "current >>> 3-stage result is incorrect"
    )

  if current4(TestValue) != expected4:
    raise newException(
      AssertionDefect,
      "current >>> 4-stage result is incorrect"
    )

  if flat2(TestValue) != expected2:
    raise newException(
      AssertionDefect,
      "flat 2-stage result is incorrect"
    )

  if flat3(TestValue) != expected3:
    raise newException(
      AssertionDefect,
      "flat 3-stage result is incorrect"
    )

  if flat4(TestValue) != expected4:
    raise newException(
      AssertionDefect,
      "flat 4-stage result is incorrect"
    )

  # ----------------------------------------------------------
  # Header
  # ----------------------------------------------------------

  echo "piper specialized-composer experiment"
  echo "iterations: ", Iterations
  echo "repeats:    ", Repeats
  echo ""

  # ----------------------------------------------------------
  # Direct noinline
  # ----------------------------------------------------------

  runBenchmark(
    "1. direct noinline 2-stage",
    benchDirectNoInline2,
    inputs
  )

  runBenchmark(
    "2. direct noinline 3-stage",
    benchDirectNoInline3,
    inputs
  )

  runBenchmark(
    "3. direct noinline 4-stage",
    benchDirectNoInline4,
    inputs
  )

  # ----------------------------------------------------------
  # Direct closure
  # ----------------------------------------------------------

  runBenchmark(
    "4. direct closure 2-stage",
    benchDirectClosure2,
    inputs
  )

  runBenchmark(
    "5. direct closure 3-stage",
    benchDirectClosure3,
    inputs
  )

  runBenchmark(
    "6. direct closure 4-stage",
    benchDirectClosure4,
    inputs
  )

  # ----------------------------------------------------------
  # Current >>> implementation
  # ----------------------------------------------------------

  runBenchmark(
    "7. current >>> 2-stage",
    benchCurrent2,
    inputs
  )

  runBenchmark(
    "8. current >>> 3-stage",
    benchCurrent3,
    inputs
  )

  runBenchmark(
    "9. current >>> 4-stage",
    benchCurrent4,
    inputs
  )

  # ----------------------------------------------------------
  # Specialized flat composition
  # ----------------------------------------------------------

  runBenchmark(
    "10. flatCompose2",
    benchFlat2,
    inputs
  )

  runBenchmark(
    "11. flatCompose3",
    benchFlat3,
    inputs
  )

  runBenchmark(
    "12. flatCompose4",
    benchFlat4,
    inputs
  )

  # ----------------------------------------------------------
  # Construction
  # ----------------------------------------------------------

  runBenchmark(
    "13. rebuild current >>> 3-stage",
    benchBuildCurrent3,
    inputs
  )

  runBenchmark(
    "14. rebuild flatCompose3",
    benchBuildFlat3,
    inputs
  )

  echo "blackHole: ", blackHole


main()