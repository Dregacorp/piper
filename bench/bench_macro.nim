import std/[
  algorithm,
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


# ============================================================================
# Test procedures
# ============================================================================

proc doubleNoInline(x: int): int {.noinline.} =
  x * 2


proc addOneNoInline(x: int): int {.noinline.} =
  x + 1


proc squareNoInline(x: int): int {.noinline.} =
  x * x


proc negateNoInline(x: int): int {.noinline.} =
  -x


# ============================================================================
# Closure baselines
# ============================================================================

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


# ============================================================================
# >>> pipelines
# ============================================================================

let current2 =
  doubleNoInline >>>
  addOneNoInline


let current3 =
  doubleNoInline >>>
  addOneNoInline >>>
  squareNoInline


let current4 =
  doubleNoInline >>>
  addOneNoInline >>>
  squareNoInline >>>
  negateNoInline


# ============================================================================
# Explicit first-class Fn conversion
# ============================================================================

let fn3: Fn[int, int] =
  toFn(current3)


# ============================================================================
# Direct closure baselines
# ============================================================================

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


# ============================================================================
# >>> benchmarks
# ============================================================================

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


# ============================================================================
# :> fused benchmarks
# ============================================================================

proc benchPipe2(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      x :>
      doubleNoInline :>
      addOneNoInline

  total


proc benchPipe3(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      x :>
      doubleNoInline :>
      addOneNoInline :>
      squareNoInline

  total


proc benchPipe4(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      x :>
      doubleNoInline :>
      addOneNoInline :>
      squareNoInline :>
      negateNoInline

  total


# ============================================================================
# First-class Fn benchmark
# ============================================================================

proc benchFn3(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      fn3(x)

  total


# ============================================================================
# Rebuilding >>> each iteration
# ============================================================================

proc benchBuildCurrent3(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    let pipeline =
      doubleNoInline >>>
      addOneNoInline >>>
      squareNoInline

    total +=
      pipeline(x)

  total


# ============================================================================
# Explicit toFn construction each iteration
# ============================================================================

proc benchBuildToFn3(
    inputs: openArray[int]
  ): int {.noinline.} =

  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    let pipeline =
      doubleNoInline >>>
      addOneNoInline >>>
      squareNoInline

    let fn =
      toFn(pipeline)

    total +=
      fn(x)

  total


# ============================================================================
# Benchmark harness
# ============================================================================

template runBenchmark(
    name: string,
    benchmark: untyped,
    inputs: untyped
  ) =

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


# ============================================================================
# Main
# ============================================================================

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

  # --------------------------------------------------------------------------
  # Correctness
  # --------------------------------------------------------------------------

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

  if fn3(TestValue) != expected3:
    raise newException(
      AssertionDefect,
      "toFn result is incorrect"
    )

  if (
    TestValue :>
    doubleNoInline :>
    addOneNoInline
  ) != expected2:
    raise newException(
      AssertionDefect,
      ":> 2-stage result is incorrect"
    )

  if (
    TestValue :>
    doubleNoInline :>
    addOneNoInline :>
    squareNoInline
  ) != expected3:
    raise newException(
      AssertionDefect,
      ":> 3-stage result is incorrect"
    )

  if (
    TestValue :>
    doubleNoInline :>
    addOneNoInline :>
    squareNoInline :>
    negateNoInline
  ) != expected4:
    raise newException(
      AssertionDefect,
      ":> 4-stage result is incorrect"
    )

  echo "piper composition benchmark"
  echo "iterations: ", Iterations
  echo "repeats:    ", Repeats
  echo ""

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

  runBenchmark(
    "4. >>> 2-stage",
    benchCurrent2,
    inputs
  )

  runBenchmark(
    "5. >>> 3-stage",
    benchCurrent3,
    inputs
  )

  runBenchmark(
    "6. >>> 4-stage",
    benchCurrent4,
    inputs
  )

  runBenchmark(
    "7. fused :> 2-stage",
    benchPipe2,
    inputs
  )

  runBenchmark(
    "8. fused :> 3-stage",
    benchPipe3,
    inputs
  )

  runBenchmark(
    "9. fused :> 4-stage",
    benchPipe4,
    inputs
  )

  runBenchmark(
    "10. first-class Fn 3-stage",
    benchFn3,
    inputs
  )

  runBenchmark(
    "11. rebuild >>> 3-stage",
    benchBuildCurrent3,
    inputs
  )

  runBenchmark(
    "12. rebuild + toFn 3-stage",
    benchBuildToFn3,
    inputs
  )

  echo "blackHole: ",
    blackHole


main()