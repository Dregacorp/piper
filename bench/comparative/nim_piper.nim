import std/[algorithm, monotimes, times, volatile]

import piper


const
  Iterations = 3_000_000
  Repeats = 9
  InputCount = 1024

  Expected2 = 26_756_370_240'i64
  Expected3 = 324_207_267_022_400'i64
  Expected4 = -324_207_267_022_400'i64


type
  Inputs = array[InputCount, int64]


var blackHole {.global.}: int64


proc doubleFn(
    x: int64
  ): int64 {.noinline.} =

  x * 2


proc addOneFn(
    x: int64
  ): int64 {.noinline.} =

  x + 1


proc squareFn(
    x: int64
  ): int64 {.noinline.} =

  x * x


proc negateFn(
    x: int64
  ): int64 {.noinline.} =

  -x


proc makeInputs(): Inputs =
  for i in 0 ..< InputCount:
    result[i] =
      ((i.int64 * 17) + 31) mod 10_000


let composed2 =
  doubleFn >>>
  addOneFn


let composed3 =
  doubleFn >>>
  addOneFn >>>
  squareFn


let composed4 =
  doubleFn >>>
  addOneFn >>>
  squareFn >>>
  negateFn


proc direct2(
    inputs: Inputs
  ): int64 {.noinline.} =

  var total = 0'i64

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      addOneFn(
        doubleFn(x)
      )

  total


proc direct3(
    inputs: Inputs
  ): int64 {.noinline.} =

  var total = 0'i64

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      squareFn(
        addOneFn(
          doubleFn(x)
        )
      )

  total


proc direct4(
    inputs: Inputs
  ): int64 {.noinline.} =

  var total = 0'i64

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      negateFn(
        squareFn(
          addOneFn(
            doubleFn(x)
          )
        )
      )

  total


proc pipe2(
    inputs: Inputs
  ): int64 {.noinline.} =

  var total = 0'i64

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      x :>
      doubleFn :>
      addOneFn

  total


proc pipe3(
    inputs: Inputs
  ): int64 {.noinline.} =

  var total = 0'i64

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      x :>
      doubleFn :>
      addOneFn :>
      squareFn

  total


proc pipe4(
    inputs: Inputs
  ): int64 {.noinline.} =

  var total = 0'i64

  for i in 0 ..< Iterations:
    let x =
      inputs[
        i and (InputCount - 1)
      ]

    total +=
      x :>
      doubleFn :>
      addOneFn :>
      squareFn :>
      negateFn

  total


proc compose2(
    inputs: Inputs
  ): int64 {.noinline.} =

  var total = 0'i64

  for i in 0 ..< Iterations:
    total +=
      composed2(
        inputs[
          i and (InputCount - 1)
        ]
      )

  total


proc compose3(
    inputs: Inputs
  ): int64 {.noinline.} =

  var total = 0'i64

  for i in 0 ..< Iterations:
    total +=
      composed3(
        inputs[
          i and (InputCount - 1)
        ]
      )

  total


proc compose4(
    inputs: Inputs
  ): int64 {.noinline.} =

  var total = 0'i64

  for i in 0 ..< Iterations:
    total +=
      composed4(
        inputs[
          i and (InputCount - 1)
        ]
      )

  total


template runBenchmark(
    language: string,
    name: string,
    benchmark: untyped,
    inputs: Inputs
  ) =

  discard benchmark(inputs)

  for _ in 0 ..< 3:
    discard benchmark(inputs)

  var samples:
    array[Repeats, int64]

  for i in 0 ..< Repeats:
    let started =
      getMonoTime()

    let result =
      benchmark(inputs)

    let finished =
      getMonoTime()

    samples[i] =
      (finished - started).inNanoseconds

    volatileStore(
      addr blackHole,
      result
    )

  samples.sort()

  let medianNs =
    samples[
      Repeats div 2
    ]

  let nsPerOp =
    medianNs.float /
    Iterations.float

  echo(
    "RESULT,",
    language,
    ",",
    name,
    ",",
    nsPerOp,
    ",",
    blackHole
  )


proc main() =
  let inputs =
    makeInputs()

  let result2 =
    direct2(inputs)

  let result3 =
    direct3(inputs)

  let result4 =
    direct4(inputs)

  doAssert(
    result2 == Expected2
  )

  doAssert(
    result3 == Expected3
  )

  doAssert(
    result4 == Expected4
  )

  for i in 0 ..< InputCount:
    let x =
      inputs[i]

    doAssert(
      (
        x :>
        doubleFn :>
        addOneFn
      ) ==
      addOneFn(
        doubleFn(x)
      )
    )

    doAssert(
      (
        x :>
        doubleFn :>
        addOneFn :>
        squareFn
      ) ==
      squareFn(
        addOneFn(
          doubleFn(x)
        )
      )
    )

    doAssert(
      (
        x :>
        doubleFn :>
        addOneFn :>
        squareFn :>
        negateFn
      ) ==
      negateFn(
        squareFn(
          addOneFn(
            doubleFn(x)
          )
        )
      )
    )

  doAssert(
    composed2(7) ==
    addOneFn(
      doubleFn(7)
    )
  )

  doAssert(
    composed3(7) ==
    squareFn(
      addOneFn(
        doubleFn(7)
      )
    )
  )

  doAssert(
    composed4(7) ==
    negateFn(
      squareFn(
        addOneFn(
          doubleFn(7)
        )
      )
    )
  )

  echo(
    "VERSION,Nim,",
    NimVersion
  )

  runBenchmark(
    "Nim",
    "direct2",
    direct2,
    inputs
  )

  runBenchmark(
    "Nim",
    "pipe2",
    pipe2,
    inputs
  )

  runBenchmark(
    "Nim",
    "compose2",
    compose2,
    inputs
  )

  runBenchmark(
    "Nim",
    "direct3",
    direct3,
    inputs
  )

  runBenchmark(
    "Nim",
    "pipe3",
    pipe3,
    inputs
  )

  runBenchmark(
    "Nim",
    "compose3",
    compose3,
    inputs
  )

  runBenchmark(
    "Nim",
    "direct4",
    direct4,
    inputs
  )

  runBenchmark(
    "Nim",
    "pipe4",
    pipe4,
    inputs
  )

  runBenchmark(
    "Nim",
    "compose4",
    compose4,
    inputs
  )


main()
