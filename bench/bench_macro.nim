import std/[algorithm, macros, monotimes, times, volatile]
import piper

const
  Iterations = 3_000_000
  Repeats = 9
  InputCount = 1024

var blackHole {.global.}: int

# ============================================================
# Experimental compile-time flat composer
#
# This is NOT part of piper yet.
#
# It accepts:
#
#   flatCompose(f, g, h)
#
# and generates exactly one closure:
#
#   proc(value) =
#     h(g(f(value)))
#
# The current >>> implementation instead creates nested
# composition closures.
# ============================================================

macro flatCompose(args: varargs[typed]): untyped =
  if args.len < 2:
    error(
      "flatCompose requires at least two functions",
      if args.len > 0:
        args[0]
      else:
        nil
    )

  # Our Nim 2.2.12 probe showed that:
  #
  #   getType(fn).repr
  #
  # is:
  #
  #   proc[int, int]
  #
  # and its AST is:
  #
  #   BracketExpr
  #     Sym "proc"
  #     Sym "int"
  #     Sym "int"
  #
  # Therefore we validate the AST shape directly instead of using
  # typeKind here.

  for index, arg in args:
    let argType = arg.getType

    if argType.kind != nnkBracketExpr:
      error(
        "flatCompose argument " &
        $index &
        " does not have the expected proc type representation",
        arg
      )

    if argType.len < 3:
      error(
        "flatCompose argument " &
        $index &
        " has an invalid proc type representation",
        arg
      )

    if argType[0].kind != nnkSym:
      error(
        "flatCompose argument " &
        $index &
        " does not contain the expected proc type marker",
        arg
      )

    if argType[0].repr != "proc":
      error(
        "flatCompose argument " &
        $index &
        " is not a proc type",
        arg
      )

  let firstType =
    args[0].getType

  let lastType =
    args[^1].getType

  let inputType =
    firstType[1]

  let outputType =
    lastType[^1]

  # Generate a hygienic parameter.
  let input =
    genSym(
      nskParam,
      "value"
    )

  # Start with:
  #
  #   f(value)
  #
  var body =
    newCall(
      args[0],
      input
    )

  # Build:
  #
  #   g(f(value))
  #   h(g(f(value)))
  #   ...
  #
  # without introducing intermediate composition closures.
  for index in 1 ..< args.len:
    body =
      newCall(
        args[index],
        body
      )

  # Generate exactly one closure.
  result =
    quote do:
      (
        proc(
          `input`: `inputType`
        ): `outputType` =
          `body`
      )

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
# Macro-generated flat pipelines
#
# Explicitly type them as Fn values.
#
# This also gives us a compile-time compatibility check:
# the generated closure must remain assignable to Fn[A, B].
# ============================================================

let macro2: Fn[int, int] =
  flatCompose(
    doubleClosure,
    addOneClosure
  )


let macro3: Fn[int, int] =
  flatCompose(
    doubleClosure,
    addOneClosure,
    squareClosure
  )


let macro4: Fn[int, int] =
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
      inputs[i and (InputCount - 1)]

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
      inputs[i and (InputCount - 1)]

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
      inputs[i and (InputCount - 1)]

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
      inputs[i and (InputCount - 1)]

    total +=
      current2(x)

  total


proc benchCurrent3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[i and (InputCount - 1)]

    total +=
      current3(x)

  total


proc benchCurrent4(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[i and (InputCount - 1)]

    total +=
      current4(x)

  total

# ============================================================
# Macro-generated flat benchmarks
# ============================================================

proc benchMacro2(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[i and (InputCount - 1)]

    total +=
      macro2(x)

  total


proc benchMacro3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[i and (InputCount - 1)]

    total +=
      macro3(x)

  total


proc benchMacro4(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[i and (InputCount - 1)]

    total +=
      macro4(x)

  total

# ============================================================
# Rebuilding each iteration
# ============================================================

proc benchBuildCurrent3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[i and (InputCount - 1)]

    let pipeline =
      doubleClosure >>>
      addOneClosure >>>
      squareClosure

    total +=
      pipeline(x)

  total


proc benchBuildMacro3(
    inputs: openArray[int]
  ): int {.noinline.} =
  var total = 0

  for i in 0 ..< Iterations:
    let x =
      inputs[i and (InputCount - 1)]

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
  discard benchmark(inputs)

  var samples: array[Repeats, int64]

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
    samples[Repeats div 2]

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

  if macro2(TestValue) != expected2:
    raise newException(
      AssertionDefect,
      "macro 2-stage result is incorrect"
    )

  if macro3(TestValue) != expected3:
    raise newException(
      AssertionDefect,
      "macro 3-stage result is incorrect"
    )

  if macro4(TestValue) != expected4:
    raise newException(
      AssertionDefect,
      "macro 4-stage result is incorrect"
    )

  # ----------------------------------------------------------
  # Header
  # ----------------------------------------------------------

  echo "piper macro-composition experiment"
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
  # Existing >>> implementation
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
  # Macro-generated flat implementation
  # ----------------------------------------------------------

  runBenchmark(
    "7. macro flat 2-stage",
    benchMacro2,
    inputs
  )

  runBenchmark(
    "8. macro flat 3-stage",
    benchMacro3,
    inputs
  )

  runBenchmark(
    "9. macro flat 4-stage",
    benchMacro4,
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
    "11. rebuild macro flat 3-stage",
    benchBuildMacro3,
    inputs
  )

  echo "blackHole: ",
    blackHole


main()