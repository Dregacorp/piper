# piper/examples/mixing.nim
#
# Shows :> mixing with >>> without parentheses.

import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x
proc negate(x: int): int = -x
proc toStr(x: int): string = $x
proc strLen(s: string): int = s.len

echo "--- pure :> chains ---"
echo 5 :> double :> addOne :> square          # 121
echo 3 :> double :> addOne :> toStr           # "7"
echo ""

echo "--- pure >>> composition ---"
let mathify = double >>> addOne >>> square
echo mathify(5)                               # 121
echo mathify(3)                               # 49
echo ""

echo "--- :> with >>> (the mixing) ---"
echo 5 :> double >>> addOne >>> square        # 121
echo 3 :> double >>> addOne >>> square        # 49
echo 5 :> double >>> addOne >>> toStr         # "11"
echo ""

echo "--- multiple :> and >>> in one chain ---"
echo 3 :> double >>> addOne :> square         # 49
echo 3 :> double >>> addOne :> square >>> toStr   # "49"
echo 3 :> double >>> addOne :> square :> negate   # -49
echo ""

echo "--- :> with a bound composition ---"
echo 5 :> mathify                             # 121
echo 5 :> mathify :> mathify                  # 59049
echo ""

echo "--- mixed with strings ---"
echo 42 :> toStr >>> strLen                   # 2
echo 12345 :> toStr >>> strLen :> double      # 10
echo ""

echo "--- multiple starting values ---"
for n in 1..5:
  echo n, " :> double >>> addOne >>> square = ",
       (n :> double >>> addOne >>> square)
echo ""

echo "done"