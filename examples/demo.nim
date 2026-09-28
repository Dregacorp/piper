# piper/examples/demo.nim
#
# End-to-end demo of piper.

import std/strutils
import piper

# ------------------------------------------------------------------
# Some functions to compose
# ------------------------------------------------------------------

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x
proc negate(x: int): int = -x
proc toStr(x: int): string = $x
proc strLen(s: string): int = s.len
proc repeat2(s: string): string = s & s
proc toUpper(s: string): string = s.toUpperAscii

# ------------------------------------------------------------------
# Demo 1: :> runs immediately, value in, value out
# ------------------------------------------------------------------

echo "=== 1. :> pipes a value through functions ==="
echo "5 :> double                     = ", (5 :> double)
echo "5 :> double :> addOne           = ", (5 :> double :> addOne)
echo "5 :> double :> addOne :> square = ", (5 :> double :> addOne :> square)
echo "3 :> double :> addOne :> toStr  = ", (3 :> double :> addOne :> toStr)
echo ""

# ------------------------------------------------------------------
# Demo 2: >>> builds a reusable function
# ------------------------------------------------------------------

echo "=== 2. >>> builds a new function ==="
let pipeline = double >>> addOne >>> square >>> toStr
echo "pipeline = double >>> addOne >>> square >>> toStr"
echo "pipeline(3)  = ", pipeline(3)
echo "pipeline(5)  = ", pipeline(5)
echo "pipeline(0)  = ", pipeline(0)
echo "pipeline(10) = ", pipeline(10)
echo ""

# ------------------------------------------------------------------
# Demo 3: same pipeline reused with :>
# ------------------------------------------------------------------

echo "=== 3. Reuse the same composed function with :> ==="
for n in 1..5:
  echo "pipeline(", n, ") = ", pipeline(n)
echo ""

# ------------------------------------------------------------------
# Demo 4: partial pipelines and composition
# ------------------------------------------------------------------

echo "=== 4. Build partial pipelines and compose further ==="
let base    = double >>> addOne
let squared = base >>> square
let asStr   = squared >>> toStr
echo "base(10)    = ", base(10)
echo "squared(10) = ", squared(10)
echo "asStr(10)   = ", asStr(10)
echo ""

# ------------------------------------------------------------------
# Demo 5: cross-type pipelines
# ------------------------------------------------------------------

echo "=== 5. Cross-type pipelines ==="
let describe = double >>> toStr >>> repeat2 >>> strLen
echo "describe(5)  = ", describe(5)
echo "describe(50) = ", describe(50)
echo ""

let shout = toStr >>> repeat2 >>> toUpper
echo "shout(42) = ", shout(42)
echo ""

# ------------------------------------------------------------------
# Demo 6: Fn as a first-class value
# ------------------------------------------------------------------

echo "=== 6. Fn values are first-class ==="
let f: Fn[int, int] = double >>> addOne
proc applyTo(n: int, g: Fn[int, int]): int =
  g(n)

echo "applyTo(100, f) = ", applyTo(100, f)

let pipelines: seq[Fn[int, int]] = @[
  double >>> addOne,
  addOne >>> double,
  double >>> square,
]
echo "pipelines[0](5) = ", pipelines[0](5)
echo "pipelines[1](5) = ", pipelines[1](5)
echo "pipelines[2](5) = ", pipelines[2](5)
echo ""

# ------------------------------------------------------------------
# Demo 7: build time runs nothing
# ------------------------------------------------------------------

echo "=== 7. Build time vs call time ==="
var calls: seq[string] = @[]

proc tracked(x: int): int =
  calls.add("tracked(" & $x & ")")
  x * 2

proc tracked2(x: int): int =
  calls.add("tracked2(" & $x & ")")
  x + 1

echo "Building pipeline..."
let trackedPipeline = tracked >>> tracked2
echo "  calls.len after building = ", calls.len

echo "Calling pipeline(7)..."
let result = trackedPipeline(7)
echo "  result = ", result
echo "  calls  = ", calls
echo ""

# ------------------------------------------------------------------
# Demo 8: mixing :> and >>>
# ------------------------------------------------------------------

echo "=== 8. Mixing :> and >>> ==="
let basePipeline = double >>> addOne
echo "basePipeline(5) :> square = ", (basePipeline(5) :> square)
echo "5 :> double :> addOne     = ", (5 :> double :> addOne)

let mixed = double >>> addOne >>> toStr
echo "mixed(5)                  = ", mixed(5)
echo "mixed(5) :> strLen        = ", (mixed(5) :> strLen)
echo ""

# ------------------------------------------------------------------
# Demo 9: closures and captured state
# ------------------------------------------------------------------

echo "=== 9. Closures and captured state ==="

proc makeAdder(n: int): Fn[int, int] =
  result = proc(x: int): int = x + n

let add5  = makeAdder(5)
let add10 = makeAdder(10)
let add15 = add5 >>> add10
echo "add5(0)   = ", add5(0)
echo "add10(0)  = ", add10(0)
echo "add15(0)  = ", add15(0)
echo "add15(100)= ", add15(100)
echo ""

# ------------------------------------------------------------------
# Demo 10: edge cases
# ------------------------------------------------------------------

echo "=== 10. Edge cases ==="
echo "0  :> double :> addOne :> square = ", (0 :> double :> addOne :> square)
echo "-1 :> double :> addOne :> square = ", (-1 :> double :> addOne :> square)
echo "-5 :> double :> negate           = ", (-5 :> double :> negate)
echo ""

echo "All demos completed."