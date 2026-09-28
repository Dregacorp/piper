import std/[
  algorithm,
  macros,
  monotimes,
  times,
  volatile
]

import piper

const
  Iterations = 3_000_000
  Repeats = 9
  InputCount = 1024

var blackHole {.global.}: int

# ============================================================
# Test functions
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
# Existing >>> implementation
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
# Production flatCompose implementation
#
# This is the public macro from piper/fcompose.nim.
# ============================================================

let flat2: Fn[int, int] =
  flatCompose(
    doubleClosure,
    addOneClosure
  )


let flat3: Fn[int, int] =
  flatCompose(
    doubleClosure,
    addOneClosure,
    squareClosure
  )


let flat4: Fn[int, int] =
  flatCompose(
    doubleClosure,
    addOneClosure,
    squareClosure,
    negateClosure
  )

# ============================================================
# Direct closure baselines
# ============================================================

proc benchDirectClosure2(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

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
    let x =
      inputs[
        i and (InputCount - 1)
      ]

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
    let x =
      inputs[
        i and (InputCount - 1)
      ]

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
# Current >>> benchmarks
# ============================================================

proc benchCurrent2(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      current2(x)

  total


proc benchCurrent3(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      current3(x)

  total


proc benchCurrent4(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      current4(x)

  total

# ============================================================
# flatCompose benchmarks
# ============================================================

proc benchFlat2(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      flat2(x)

  total


proc benchFlat3(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      flat3(x)

  total


proc benchFlat4(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      flat4(x)

  total

# ============================================================
# Rebuilding current >>> each iteration
# ============================================================

proc benchBuildCurrent3(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    let pipeline: Fn[int, int] =
      doubleClosure >>>
      addOneClosure >>>
      squareClosure

    total +=
      pipeline(x)

  total

# ============================================================
# Rebuilding flatCompose each iteration
# ============================================================

proc benchBuildFlat3(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    let pipeline: Fn[int, int] =
      flatCompose(
        doubleClosure,
        addOneClosure,
        squareClosure
      )

    total +=
      pipeline(x)

  total

# ============================================================
# Benchmark harness
# ============================================================

template runBenchmark(
    name: string,
    benchmark: untyped,
    inputs: untyped
  ) =

  # Warm-up.
  discard benchmark(inputs)

  var samples:
    array[Repeats, int64]

  for runIndex in 0 ..< Repeats:
    let start =
      getMonoTime()

    let result =
      benchmark(inputs)

    let finish =
      getMonoTime()

    samples[runIndex] =
      (finish - start).inNanoseconds

    volatileStore(
      addr blackHole,
      result
    )

  samples.sort()

  let medianNs =
    samples[
      Repeats div 2
    ]

  let nsPerOperation =
    medianNs.float /
    Iterations.float

  echo name

  echo "  median: ",
    medianNs,
    " ns"

  echo "  ns/op:  ",
    nsPerOperation

  echo ""

# ============================================================
# Main
# ============================================================

proc main() =
  var inputs:
    array[InputCount, int]

  var state =
    0x13579B

  for i in 0 ..< InputCount:
    state =
      state xor
      (state shl 13)

    state =
      state xor
      (state shr 17)

    state =
      state xor
      (state shl 5)

    inputs[i] =
      (state mod 10000) +
      i

  # ----------------------------------------------------------
  # Correctness
  # ----------------------------------------------------------

  const TestValue = 7

  let expected2 =
    addOneNoInline(
      doubleNoInline(
        TestValue
      )
    )

  let expected3 =
    squareNoInline(
      addOneNoInline(
        doubleNoInline(
          TestValue
        )
      )
    )

  let expected4 =
    negateNoInline(
      squareNoInline(
        addOneNoInline(
          doubleNoInline(
            TestValue
          )
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
      "flatCompose 2-stage result is incorrect"
    )

  if flat3(TestValue) != expected3:
    raise newException(
      AssertionDefect,
      "flatCompose 3-stage result is incorrect"
    )

  if flat4(TestValue) != expected4:
    raise newException(
      AssertionDefect,
      "flatCompose 4-stage result is incorrect"
    )

  # ----------------------------------------------------------
  # Header
  # ----------------------------------------------------------

  echo "piper flat-composition benchmark"
  echo "iterations: ",
    Iterations

  echo "repeats:    ",
    Repeats

  echo ""

  # ----------------------------------------------------------
  # Direct closure
  # ----------------------------------------------------------

  runBenchmark(
    "1. direct closure 2-stage",
    benchDirectClosure2,
    inputs
  )

  runBenchmark(
    "2. direct closure 3-stage",
    benchDirectClosure3,
    inputs
  )

  runBenchmark(
    "3. direct closure 4-stage",
    benchDirectClosure4,
    inputs
  )

  # ----------------------------------------------------------
  # Current >>>
  # ----------------------------------------------------------

  runBenchmark(
    "4. current >>> 2-stage",
    benchCurrent2,
    inputs
  )

  runBenchmark(
    "5. current >>> 3-stage",
    benchCurrent3,
    inputs
  )

  runBenchmark(
    "6. current >>> 4-stage",
    benchCurrent4,
    inputs
  )

  # ----------------------------------------------------------
  # flatCompose
  # ----------------------------------------------------------

  runBenchmark(
    "7. flatCompose 2-stage",
    benchFlat2,
    inputs
  )

  runBenchmark(
    "8. flatCompose 3-stage",
    benchFlat3,
    inputs
  )

  runBenchmark(
    "9. flatCompose 4-stage",
    benchFlat4,
    inputs
  )

  # ----------------------------------------------------------
  # Construction
  # ----------------------------------------------------------

  runBenchmark(
    "10. rebuild current >>> 3-stage",
    benchBuildCurrent3,
    inputs
  )

  runBenchmark(
    "11. rebuild flatCompose 3-stage",
    benchBuildFlat3,
    inputs
  )

  echo "blackHole: ",
    blackHole


main()