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
# Closure versions of the noinline functions
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
#
# These are the implementation we are investigating.
# ============================================================

let composed2 =
  doubleClosure >>>
  addOneClosure


let composed3 =
  doubleClosure >>>
  addOneClosure >>>
  squareClosure


let composed4 =
  doubleClosure >>>
  addOneClosure >>>
  squareClosure >>>
  negateClosure

# ============================================================
# Manually flattened closures
#
# IMPORTANT:
#
# These are NOT new piper features.
#
# They are the performance target we want to measure.
#
# Instead of:
#
#   composed3(x)
#       |
#       v
#   composed2(x)
#       |
#       v
#   double -> addOne
#
# the body directly contains:
#
#   square(addOne(double(x)))
#
# The closure itself is still a closure, so this gives us a much
# fairer comparison with >>> than comparing against direct procs.
# ============================================================

let flat2: Fn[int, int] =
  proc(x: int): int =
    addOneClosure(
      doubleClosure(x)
    )


let flat3: Fn[int, int] =
  proc(x: int): int =
    squareClosure(
      addOneClosure(
        doubleClosure(x)
      )
    )


let flat4: Fn[int, int] =
  proc(x: int): int =
    negateClosure(
      squareClosure(
        addOneClosure(
          doubleClosure(x)
        )
      )
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
#
# These call the individual closure values directly.
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
# Current >>> composition
# ============================================================

proc benchCompose2(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total += composed2(x)

  total


proc benchCompose3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total += composed3(x)

  total


proc benchCompose4(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x = inputs[i and (InputCount - 1)]

    total += composed4(x)

  total

# ============================================================
# Manually flattened closures
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
# Benchmark harness
# ============================================================

template runBenchmark(
    name: string,
    benchmark: untyped,
    inputs: untyped
  ) =
  # Warm up.
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
      "unexpected 2-stage baseline result: " &
      $expected2
    )

  if expected3 != 225:
    raise newException(
      AssertionDefect,
      "unexpected 3-stage baseline result: " &
      $expected3
    )

  if expected4 != -225:
    raise newException(
      AssertionDefect,
      "unexpected 4-stage baseline result: " &
      $expected4
    )

  if composed2(TestValue) != expected2:
    raise newException(
      AssertionDefect,
      ">>> 2-stage result is incorrect"
    )

  if composed3(TestValue) != expected3:
    raise newException(
      AssertionDefect,
      ">>> 3-stage result is incorrect"
    )

  if composed4(TestValue) != expected4:
    raise newException(
      AssertionDefect,
      ">>> 4-stage result is incorrect"
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

  echo "piper flat-composition experiment"
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
  # Direct closures
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
  # Existing >>> implementation
  # ----------------------------------------------------------

  runBenchmark(
    "7. >>> 2-stage",
    benchCompose2,
    inputs
  )

  runBenchmark(
    "8. >>> 3-stage",
    benchCompose3,
    inputs
  )

  runBenchmark(
    "9. >>> 4-stage",
    benchCompose4,
    inputs
  )

  # ----------------------------------------------------------
  # Manually flattened closures
  # ----------------------------------------------------------

  runBenchmark(
    "10. manually flat 2-stage",
    benchFlat2,
    inputs
  )

  runBenchmark(
    "11. manually flat 3-stage",
    benchFlat3,
    inputs
  )

  runBenchmark(
    "12. manually flat 4-stage",
    benchFlat4,
    inputs
  )

  echo "blackHole: ", blackHole


main()