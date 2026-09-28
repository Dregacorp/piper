# piper/tests/test_pipe.nim
#
# Dedicated tests for pipe.nim: the :> template.

import std/unittest
import std/strutils
import piper/pipe

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x
proc negate(x: int): int = -x
proc toStr(x: int): string = $x
proc strLen(s: string): int = s.len
proc repeat2(s: string): string = s & s
proc toUpper(s: string): string = s.toUpperAscii
proc addExclaim(s: string): string = s & "!"

suite "pipe":

  # ----------------------------------------------------------------
  # Basic single-stage piping
  # ----------------------------------------------------------------

  test ":> pipes a value through one function":
    check (5 :> double) == 10
    check (5 :> addOne) == 6
    check (5 :> square) == 25
    check (5 :> negate) == -5

  test ":> works with string functions":
    check ("hi" :> toUpper) == "HI"
    check ("hi" :> addExclaim) == "hi!"
    check ("hi" :> repeat2) == "hihi"

  test ":> works across types in one step":
    check (5 :> toStr) == "5"
    check ("hello" :> strLen) == 5

  # ----------------------------------------------------------------
  # Chaining
  # ----------------------------------------------------------------

  test ":> chains two functions":
    check (5 :> double :> addOne) == 11
    check (5 :> addOne :> double) == 12

  test ":> chains three functions":
    check (3 :> double :> addOne :> square) == 49
    check (0 :> double :> addOne :> square) == 1

  test ":> chains across types":
    check (3 :> double :> addOne :> toStr) == "7"
    check (5 :> double :> addOne :> toStr :> strLen) == 2

  test ":> chains many stages":
    check (1 :> double :> addOne :> double :> addOne :> double) == 14

  # ----------------------------------------------------------------
  # Order matters
  # ----------------------------------------------------------------

  test ":> evaluates left to right":
    let a = 5 :> double :> addOne
    let b = 5 :> addOne :> double
    check a != b
    check a == 11
    check b == 12

  # ----------------------------------------------------------------
  # Evaluation happens immediately
  # ----------------------------------------------------------------

  test ":> runs immediately, not later":
    var counter = 0

    proc tracked(x: int): int =
      inc counter
      x * 2

    let y = 5 :> tracked
    check counter == 1
    check y == 10

  test ":> runs the full chain at once":
    var calls: seq[string] = @[]

    proc first(x: int): int =
      calls.add("first(" & $x & ")")
      x + 1

    proc second(x: int): int =
      calls.add("second(" & $x & ")")
      x * 10

    proc third(x: int): string =
      calls.add("third(" & $x & ")")
      $x

    let result = 5 :> first :> second :> third
    check result == "60"
    check calls == @["first(5)", "second(6)", "third(60)"]

  # ----------------------------------------------------------------
  # Left side: any expression
  # ----------------------------------------------------------------

  test ":> accepts literal on the left":
    check (10 :> double) == 20

  test ":> accepts a variable on the left":
    let x = 10
    check (x :> double) == 20

  test ":> accepts a function call on the left":
    proc make(): int = 7
    check (make() :> double) == 14

  test ":> accepts an arithmetic expression on the left":
    check ((3 + 4) :> double) == 14
    check ((10 - 2) :> double) == 16

  # ----------------------------------------------------------------
  # Right side: any callable
  # ----------------------------------------------------------------

  test ":> accepts a top-level proc":
    check (5 :> double) == 10

  test ":> accepts a lambda":
    check (5 :> (proc(x: int): int = x + 100)) == 105

  test ":> accepts a closure":
    let n = 100
    let addN = proc(x: int): int = x + n
    check (5 :> addN) == 105

  test ":> accepts a proc that itself pipes":
    proc chained(x: int): int =
      x :> double :> addOne
    check (5 :> chained) == 11

  # ----------------------------------------------------------------
  # Closures and captured state
  # ----------------------------------------------------------------

  test ":> works with a closure that captures state":
    var total = 0
    let accumulate = proc(x: int): int =
      total += x
      total

    check (5 :> accumulate) == 5
    check (5 :> accumulate) == 10
    check (5 :> accumulate) == 15

  test ":> with a function factory":
    proc makeAdder(n: int): proc(x: int): int =
      result = proc(x: int): int = x + n

    let add5  = makeAdder(5)
    let add10 = makeAdder(10)
    check (0  :> add5) == 5
    check (0  :> add10) == 10
    check (100 :> add5) == 105

  # ----------------------------------------------------------------
  # Result storage
  # ----------------------------------------------------------------

  test ":> result can be stored in a variable":
    let a = 5 :> double :> addOne
    let b = a :> square
    check a == 11
    check b == 121

  test ":> result can be used in another expression":
    let total = (5 :> double) + (10 :> double)
    check total == 30

  # ----------------------------------------------------------------
  # Different types at each stage
  # ----------------------------------------------------------------

  test ":> can change type at each step":
    check (42 :> toStr) == "42"
    check (42 :> toStr :> strLen) == 2
    check (42 :> toStr :> repeat2) == "4242"
    check (42 :> toStr :> repeat2 :> strLen) == 4

  test ":> int -> string -> int roundtrip":
    check (5 :> toStr :> strLen) == 1
    check (555 :> toStr :> strLen) == 3

  # ----------------------------------------------------------------
  # Zero and negatives
  # ----------------------------------------------------------------

  test ":> works with zero":
    check (0 :> double) == 0
    check (0 :> addOne) == 1
    check (0 :> square) == 0

  test ":> works with negatives":
    check (-5 :> double) == -10
    check (-5 :> addOne) == -4
    check (-5 :> square) == 25
    check (-5 :> negate) == 5

  test ":> handles sign changes across a chain":
    check (-3 :> double :> addOne :> square) == 25

  # ----------------------------------------------------------------
  # Chains that end with a different type
  # ----------------------------------------------------------------

  test ":> chain ending in string":
    let r = 5 :> double :> addOne :> toStr
    check r == "11"

  test ":> chain ending in bool-like predicate":
    proc isEven(x: int): bool = x mod 2 == 0
    check (4 :> isEven) == true
    check (5 :> isEven) == false
    check (4 :> double :> isEven) == true
    check (5 :> double :> isEven) == true