# piper/tests/test_mixing.nim
#
# Tests mixed :> / >>> expressions.
#
# The important property is that users do not need parentheses to
# move between value-flow (:>) and function-flow (>>>).

import std/unittest
import piper


proc double(x: int): int =
  x * 2


proc addOne(x: int): int =
  x + 1


proc square(x: int): int =
  x * x


proc negate(x: int): int =
  -x


proc toStr(x: int): string =
  $x


proc strLen(s: string): int =
  s.len


suite "mixing :> and >>>":

  # ----------------------------------------------------------------
  # Complete composition segment
  # ----------------------------------------------------------------

  test ":> applies a complete >>> segment":
    check (
      5 :>
      double >>>
      addOne >>>
      square
    ) == 121


  test ":> applies a one-function segment":
    check (
      5 :> double
    ) == 10


  # ----------------------------------------------------------------
  # Multiple segments
  # ----------------------------------------------------------------

  test "multiple composition segments":
    check (
      5 :>
      double >>>
      addOne >>>
      square :>
      negate
    ) == -121


  test "multiple segments without parentheses":
    check (
      5 :>
      double >>>
      addOne >>>
      square :>
      negate >>>
      double :>
      addOne
    ) == -241


  test "long mixed chain":
    let result =
      5 :>
      double >>>
      addOne >>>
      square :>
      negate >>>
      double :>
      addOne >>>
      double

    # 5
    # -> 10
    # -> 11
    # -> 121
    # -> -121
    # -> -242
    # -> -241
    # -> -482

    check result == -482


  test "alternating single and composed segments":
    let result =
      5 :>
      double >>>
      addOne :>
      square >>>
      negate :>
      double >>>
      addOne :>
      square

    # 5
    # -> 10
    # -> 11
    # -> 121
    # -> -121
    # -> -242
    # -> -241
    # -> 58081

    check result == 58081


  # ----------------------------------------------------------------
  # Type changes
  # ----------------------------------------------------------------

  test "mixed chain changes type":
    let result =
      5 :>
      double >>>
      addOne >>>
      toStr :>
      strLen

    check result == 2


  test "mixed chain can have multiple type changes":
    proc decorate(
        s: string
      ): string =
      "[" & s & "]"

    let result =
      5 :>
      double >>>
      toStr >>>
      decorate :>
      strLen

    check result == 4


  # ----------------------------------------------------------------
  # Bound pipelines
  # ----------------------------------------------------------------

  test "bound composition remains reusable":
    let mathify =
      double >>>
      addOne >>>
      square

    check (
      5 :> mathify
    ) == 121

    check (
      5 :>
      mathify :>
      mathify
    ) == 59049


  test "bound compositions can be chained":
    let first =
      double >>>
      addOne

    let second =
      square >>>
      negate

    check (
      5 :>
      first :>
      second
    ) == -121


  # ----------------------------------------------------------------
  # Closures
  # ----------------------------------------------------------------

  test "mixed chains accept closures":
    let addFive =
      proc(x: int): int =
        x + 5

    let result =
      5 :>
      double >>>
      addFive >>>
      square

    check result == 225


  test "mixed chains accept Fn":
    let addFive: Fn[int, int] =
      proc(x: int): int =
        x + 5

    let result =
      5 :>
      double >>>
      addFive >>>
      square

    check result == 225


  # ----------------------------------------------------------------
  # Function-producing stages
  # ----------------------------------------------------------------

  test "function-producing stages are evaluated once":
    var constructions = 0

    proc makeAdder(
        n: int
      ): Fn[int, int] =

      inc constructions

      result =
        proc(x: int): int =
          x + n

    let result =
      5 :>
      makeAdder(5) >>>
      makeAdder(10)

    check result == 20
    check constructions == 2


  # ----------------------------------------------------------------
  # Execution order
  # ----------------------------------------------------------------

  test "mixed composition preserves left-to-right execution":
    var order: seq[string] = @[]

    proc first(x: int): int =
      order.add(
        "first(" &
        $x &
        ")"
      )

      x + 1


    proc second(x: int): int =
      order.add(
        "second(" &
        $x &
        ")"
      )

      x * 10


    proc third(x: int): int =
      order.add(
        "third(" &
        $x &
        ")"
      )

      x - 3

    let result =
      5 :>
      first >>>
      second :>
      third

    check result == 57

    check order ==
      @[
        "first(5)",
        "second(6)",
        "third(60)"
      ]