# piper/examples/compose_and_apply.nim
#
# The full piper workflow:
#
#   1. Write small building-block functions.
#   2. Compose them with >>> into named "super functions".
#   3. Do this several times to build different super functions.
#   4. Pass those super functions around and apply them with :>.

import std/strutils
import piper

# ------------------------------------------------------------------
# Step 1: small building-block functions
# ------------------------------------------------------------------

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x
proc negate(x: int): int = -x

proc toStr(x: int): string = $x
proc strLen(s: string): int = s.len
proc repeat2(s: string): string = s & s
proc toUpper(s: string): string = s.toUpperAscii
proc exclaim(s: string): string = s & "!"

# ------------------------------------------------------------------
# Step 2 & 3: compose them into super functions
# ------------------------------------------------------------------

let mathify: Fn[int, int] = double >>> addOne >>> square
let stringify: Fn[int, string] = double >>> addOne >>> toStr
let describe: Fn[int, int] = double >>> toStr >>> repeat2 >>> strLen
let shout: Fn[int, string] = toStr >>> repeat2 >>> toUpper >>> exclaim
let countDigits: Fn[int, int] = toStr >>> strLen
let negDescribe: Fn[int, int] = negate >>> describe

echo "=== Super functions built with >>> ==="
echo "mathify      : x -> ((x*2)+1)^2"
echo "stringify    : x -> $(x*2+1)"
echo "describe     : x -> len(repeat2($(x*2)))"
echo "shout        : x -> upper(repeat2($x)) + \"!\""
echo "countDigits  : x -> len($x)"
echo "negDescribe  : x -> describe(-x)"
echo ""

# ------------------------------------------------------------------
# Step 4: apply each super function with :>
# ------------------------------------------------------------------

echo "=== Applying each super function with :> ==="
echo "3     :> mathify      = ", (3     :> mathify)
echo "5     :> mathify      = ", (5     :> mathify)
echo "3     :> stringify    = ", (3     :> stringify)
echo "5     :> stringify    = ", (5     :> stringify)
echo "5     :> describe     = ", (5     :> describe)
echo "50    :> describe     = ", (50    :> describe)
echo "42    :> shout        = ", (42    :> shout)
echo "12345 :> countDigits  = ", (12345 :> countDigits)
echo "-3    :> negDescribe  = ", (-3    :> negDescribe)
echo ""

# ------------------------------------------------------------------
# Storing super functions in a collection
# ------------------------------------------------------------------

echo "=== Store super functions in a list, apply with :> ==="
let intPipelines: seq[Fn[int, int]] = @[
  mathify,
  double >>> addOne,
  double >>> square,
  addOne >>> double,
  countDigits,
]

for i, p in intPipelines:
  echo "5 :> intPipelines[", i, "] = ", (5 :> p)
echo ""

# ------------------------------------------------------------------
# Passing a super function as an argument
# ------------------------------------------------------------------

echo "=== Pass a super function as an argument ==="

proc applyToAll(ns: seq[int], p: Fn[int, int]): seq[int] =
  result = @[]
  for n in ns:
    result.add(n :> p)

let numbers = @[1, 2, 3, 4]
echo "[1,2,3,4] :> mathify           = ", applyToAll(numbers, mathify)
echo "[1,2,3,4] :> double >>> addOne = ", applyToAll(numbers, double >>> addOne)
echo "[1,2,3,4] :> double >>> square = ", applyToAll(numbers, double >>> square)
echo ""

# ------------------------------------------------------------------
# Returning a super function from another function
# ------------------------------------------------------------------

echo "=== Return a super function from another function ==="

proc makeScaler(factor: int): Fn[int, int] =
  result = proc(x: int): int = x * factor

let triple   = makeScaler(3)
let timesTen = makeScaler(10)
echo "5 :> triple       = ", (5 :> triple)
echo "5 :> timesTen     = ", (5 :> timesTen)

let scalingPipeline = triple >>> addOne >>> square
echo "5 :> (triple >>> addOne >>> square) = ", (5 :> scalingPipeline)
echo ""

# ------------------------------------------------------------------
# Chaining :> to apply then pipe further
# ------------------------------------------------------------------

echo "=== Chaining super functions with :> ==="
echo "3   :> mathify :> stringify   = ", (3   :> mathify :> stringify)
echo "3   :> stringify :> strLen    = ", (3   :> stringify :> strLen)
echo "100 :> countDigits :> double = ", (100 :> countDigits :> double)
echo ""

# ------------------------------------------------------------------
# One-shot inline composition
# ------------------------------------------------------------------

echo "=== Compose inline, apply with :> ==="
echo "7 :> (double >>> addOne >>> square) = ", (7 :> (double >>> addOne >>> square))
echo ""

echo "=== Done ==="