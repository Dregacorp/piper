# piper/tests/test1.nim

import std/unittest
import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x
proc toStr(x: int): string = $x

suite "piper":

  # ----------------------------------------------------------------
  # :> : value flows through functions immediately
  # ----------------------------------------------------------------

  test ":> pipes a value through one function":
    check (5 :> double) == 10
    check (5 :> addOne) == 6
    check (5 :> square) == 25

  test ":> chains multiple functions":
    check (5 :> double :> addOne) == 11
    check (5 :> double :> addOne :> square) == 121
    check (3 :> double :> addOne :> toStr) == "7"

  # ----------------------------------------------------------------
  # >>> : functions compose into a new function
  # ----------------------------------------------------------------

  test ">>> composes two functions":
    let pipeline = double >>> addOne
    check pipeline(5) == 11
    check pipeline(0) == 1
    check pipeline(10) == 21

  test ">>> chains more functions":
    let pipeline = double >>> addOne >>> square >>> toStr
    check pipeline(3) == "49"
    check pipeline(5) == "121"
    check pipeline(0) == "1"

  test ">>> result is a reusable function":
    let pipeline = double >>> addOne
    check pipeline(1) == 3
    check pipeline(2) == 5
    check pipeline(3) == 7
    check pipeline(100) == 201

  test ">>> builds partial pipelines that extend further":
    let base    = double >>> addOne
    let squared = base >>> square
    let final   = squared >>> toStr
    check base(10) == 21
    check squared(10) == 441
    check final(10) == "441"

  test ">>> composed function is first-class":
    let pipeline = double >>> addOne
    proc applyTo(n: int, f: Fn[int, int]): int =
      f(n)
    check applyTo(5, pipeline) == 11
    check applyTo(100, pipeline) == 201

  test ">>> build time runs nothing, call time runs everything":
    var calls: seq[string] = @[]

    proc trackedDouble(x: int): int =
      calls.add("double(" & $x & ")")
      x * 2

    proc trackedAddOne(x: int): int =
      calls.add("addOne(" & $x & ")")
      x + 1

    let pipeline = trackedDouble >>> trackedAddOne
    check calls.len == 0

    let result = pipeline(3)
    check result == 7
    check calls == @["double(3)", "addOne(6)"]