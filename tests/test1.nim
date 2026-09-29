# piper/tests/test1.nim

import std/unittest
import piper


proc double(x: int): int =
  x * 2


proc addOne(x: int): int =
  x + 1


proc square(x: int): int =
  x * x


proc toStr(x: int): string =
  $x


suite "piper":

  # ----------------------------------------------------------------
  # :>
  # ----------------------------------------------------------------

  test ":> pipes a value through one function":
    check (
      5 :> double
    ) == 10

    check (
      5 :> addOne
    ) == 6

    check (
      5 :> square
    ) == 25


  test ":> chains multiple functions":
    check (
      5 :>
      double :>
      addOne
    ) == 11

    check (
      5 :>
      double :>
      addOne :>
      square
    ) == 121

    check (
      3 :>
      double :>
      addOne :>
      toStr
    ) == "7"


  # ----------------------------------------------------------------
  # >>>
  # ----------------------------------------------------------------

  test ">>> composes two functions":
    let pipeline =
      double >>>
      addOne

    check pipeline(5) == 11
    check pipeline(0) == 1
    check pipeline(10) == 21


  test ">>> chains more functions":
    let pipeline =
      double >>>
      addOne >>>
      square >>>
      toStr

    check pipeline(3) == "49"
    check pipeline(5) == "121"
    check pipeline(0) == "1"


  test ">>> result is reusable":
    let pipeline =
      double >>>
      addOne

    check pipeline(1) == 3
    check pipeline(2) == 5
    check pipeline(3) == 7
    check pipeline(100) == 201


  test ">>> builds partial pipelines":
    let base =
      double >>>
      addOne

    let squared =
      base >>>
      square

    let final =
      squared >>>
      toStr

    check base(10) == 21
    check squared(10) == 441
    check final(10) == "441"


  # ----------------------------------------------------------------
  # Explicit Fn conversion
  # ----------------------------------------------------------------

  test "toFn converts a fast pipeline to Fn":
    let pipeline: Fn[int, int] =
      toFn(
        double >>>
        addOne
      )

    check pipeline(5) == 11
    check pipeline(100) == 201


  test "Fn can be passed to another proc":
    proc applyTo(
        n: int,
        f: Fn[int, int]
      ): int =
      f(n)

    let pipeline: Fn[int, int] =
      toFn(
        double >>>
        addOne
      )

    check applyTo(5, pipeline) == 11
    check applyTo(100, pipeline) == 201


  test "Fn can be explicitly built from a closure":
    let addFive: Fn[int, int] =
      proc(x: int): int =
        x + 5

    let pipeline: Fn[int, int] =
      toFn(
        addFive >>>
        square
      )

    check pipeline(5) == 100


  # ----------------------------------------------------------------
  # Construction behavior
  # ----------------------------------------------------------------

  test ">>> construction does not execute stages":
    var calls: seq[string] = @[]

    proc trackedDouble(x: int): int =
      calls.add(
        "double(" &
        $x &
        ")"
      )

      x * 2


    proc trackedAddOne(x: int): int =
      calls.add(
        "addOne(" &
        $x &
        ")"
      )

      x + 1

    let pipeline =
      trackedDouble >>>
      trackedAddOne

    check calls.len == 0

    let result =
      pipeline(3)

    check result == 7

    check calls ==
      @[
        "double(3)",
        "addOne(6)"
      ]


  # ----------------------------------------------------------------
  # Mixed syntax
  # ----------------------------------------------------------------

  test ">>> and :> can be mixed without parentheses":
    let result =
      5 :>
      double >>>
      addOne >>>
      square :>
      toStr

    check result == "121"