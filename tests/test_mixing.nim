# piper/tests/test_mixing.nim
#
# Tests that :> mixes with >>> without parentheses.

import std/unittest
import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x
proc negate(x: int): int = -x
proc toStr(x: int): string = $x
proc strLen(s: string): int = s.len

suite "mixing :> and >>>":

  # ----------------------------------------------------------------
  # Basic :> with >>>
  # ----------------------------------------------------------------

  test ":> pipes a value through a composition":
    check (5 :> double >>> addOne >>> square) == 121
    check (3 :> double >>> addOne >>> square) == 49
    check (0 :> double >>> addOne >>> square) == 1
    check (-1 :> double >>> addOne >>> square) == 1

  test ":> with a single composed stage":
    check (5 :> double >>> addOne) == 11
    check (5 :> double) == 10

  test ":> across types":
    check (5 :> double >>> addOne >>> toStr) == "11"
    check (5 :> toStr) == "5"
    check (12345 :> toStr >>> strLen) == 5

  # ----------------------------------------------------------------
  # Multiple :> in one chain
  # ----------------------------------------------------------------

  test "multiple :> operators":
    check (3 :> double >>> addOne :> square) == 49
    check (3 :> double >>> addOne :> square >>> toStr) == "49"
    check (3 :> double >>> addOne :> square :> negate) == -49

  test ":> is left-associative":
    let a = (3 :> double >>> addOne) :> square
    let b = 3 :> double >>> addOne :> square
    check a == b

  # ----------------------------------------------------------------
  # :> with a bound composition
  # ----------------------------------------------------------------

  test ":> with a bound composition":
    let mathify = double >>> addOne >>> square
    check (5 :> mathify) == 121
    # mathify(5)   = (5*2 + 1)^2   = 11^2  = 121
    # mathify(121) = (121*2 + 1)^2 = 243^2 = 59049
    check (5 :> mathify :> mathify) == 59049

  test ":> with different bound compositions":
    let p1 = double >>> addOne
    let p2 = square >>> toStr
    check (5 :> p1) == 11
    check (5 :> p1 :> p2) == "121"

  # ----------------------------------------------------------------
  # Mixed :> and >>> in one chain
  # ----------------------------------------------------------------

  test ":> and >>> in one chain":
    check (5 :> double >>> addOne) == 11
    check (5 :> double >>> addOne >>> square) == 121

  test "chained >>> groups as one function":
    let p = double >>> addOne >>> square
    check (5 :> p) == 121

  # ----------------------------------------------------------------
  # Edge cases
  # ----------------------------------------------------------------

  test ":> works with zero and negatives":
    check (0 :> double >>> addOne >>> square) == 1
    check (-1 :> double >>> addOne >>> square) == 1
    check (-5 :> double >>> negate) == 10