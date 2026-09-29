open System
open System.Diagnostics
open System.Runtime.CompilerServices


[<Literal>]
let Iterations = 3_000_000


[<Literal>]
let Repeats = 9


[<Literal>]
let InputCount = 1024L


[<AbstractClass; Sealed>]
type Ops =
    [<MethodImpl(MethodImplOptions.NoInlining)>]
    static member Double(x: int64) : int64 =
        x * 2L

    [<MethodImpl(MethodImplOptions.NoInlining)>]
    static member AddOne(x: int64) : int64 =
        x + 1L

    [<MethodImpl(MethodImplOptions.NoInlining)>]
    static member Square(x: int64) : int64 =
        x * x

    [<MethodImpl(MethodImplOptions.NoInlining)>]
    static member Negate(x: int64) : int64 =
        -x


let doubleF (x: int64) : int64 =
    Ops.Double x


let addOneF (x: int64) : int64 =
    Ops.AddOne x


let squareF (x: int64) : int64 =
    Ops.Square x


let negateF (x: int64) : int64 =
    Ops.Negate x


let inputs : int64 array =
    Array.init
        (int InputCount)
        (fun i ->
            ((int64 i * 17L) + 31L) % 10_000L)


let composed2 =
    doubleF >> addOneF


let composed3 =
    doubleF >> addOneF >> squareF


let composed4 =
    doubleF >> addOneF >> squareF >> negateF


let index (i: int) : int =
    i &&& (int InputCount - 1)


let direct2 () : int64 =
    let mutable total = 0L

    for i = 0 to Iterations - 1 do
        let x =
            inputs[index i]

        total <-
            total +
            addOneF(
                doubleF x
            )

    total


let direct3 () : int64 =
    let mutable total = 0L

    for i = 0 to Iterations - 1 do
        let x =
            inputs[index i]

        total <-
            total +
            squareF(
                addOneF(
                    doubleF x
                )
            )

    total


let direct4 () : int64 =
    let mutable total = 0L

    for i = 0 to Iterations - 1 do
        let x =
            inputs[index i]

        total <-
            total +
            negateF(
                squareF(
                    addOneF(
                        doubleF x
                    )
                )
            )

    total


let pipe2 () : int64 =
    let mutable total = 0L

    for i = 0 to Iterations - 1 do
        let x =
            inputs[index i]

        let value =
            x
            |> doubleF
            |> addOneF

        total <-
            total + value

    total


let pipe3 () : int64 =
    let mutable total = 0L

    for i = 0 to Iterations - 1 do
        let x =
            inputs[index i]

        let value =
            x
            |> doubleF
            |> addOneF
            |> squareF

        total <-
            total + value

    total


let pipe4 () : int64 =
    let mutable total = 0L

    for i = 0 to Iterations - 1 do
        let x =
            inputs[index i]

        let value =
            x
            |> doubleF
            |> addOneF
            |> squareF
            |> negateF

        total <-
            total + value

    total


let composeRun
    (pipeline: int64 -> int64)
    : int64 =

    let mutable total = 0L

    for i = 0 to Iterations - 1 do
        total <-
            total +
            pipeline(
                inputs[index i]
            )

    total


let median
    (values: int64 array)
    : int64 =

    let copy =
        Array.copy values

    Array.sortInPlace copy

    copy[Repeats / 2]


let monotonicNs () : int64 =
    let ticks =
        Stopwatch.GetTimestamp()

    ticks
    * 1_000_000_000L
    / Stopwatch.Frequency


let measure
    (name: string)
    (f: unit -> int64) =

    ignore(f())

    for _ = 1 to 3 do
        ignore(f())

    let samples =
        Array.init
            Repeats
            (fun _ ->
                let startNs =
                    monotonicNs()

                let result =
                    f()

                let finishNs =
                    monotonicNs()

                GC.KeepAlive(result)

                finishNs - startNs)

    let med =
        median samples

    let nsPerOp =
        float med /
        float Iterations

    let checksum =
        f()

    printfn
        "RESULT,F#,%s,%.6f,%d"
        name
        nsPerOp
        checksum


let expected2 =
    addOneF(
        doubleF 7L
    )


let expected3 =
    squareF(
        addOneF(
            doubleF 7L
        )
    )


let expected4 =
    negateF(
        squareF(
            addOneF(
                doubleF 7L
            )
        )
    )


if direct2() <> 26_756_370_240L then
    failwith "direct2 checksum mismatch"


if direct3() <> 324_207_267_022_400L then
    failwith "direct3 checksum mismatch"


if direct4() <> -324_207_267_022_400L then
    failwith "direct4 checksum mismatch"


if composed2 7L <> expected2 then
    failwith "compose2 correctness failure"


if composed3 7L <> expected3 then
    failwith "compose3 correctness failure"


if composed4 7L <> expected4 then
    failwith "compose4 correctness failure"


printfn
    "VERSION,F#,.NET-%s"
    (Environment.Version.ToString())


measure
    "direct2"
    direct2


measure
    "pipe2"
    pipe2


measure
    "compose2"
    (fun () ->
        composeRun composed2)


measure
    "direct3"
    direct3


measure
    "pipe3"
    pipe3


measure
    "compose3"
    (fun () ->
        composeRun composed3)


measure
    "direct4"
    direct4


measure
    "pipe4"
    pipe4


measure
    "compose4"
    (fun () ->
        composeRun composed4)