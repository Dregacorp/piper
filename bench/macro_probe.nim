import std/macros
import piper

type
  TestFn[A, B] = proc(a: A): B {.closure.}

proc double(x: int): int =
  x * 2


proc addOne(x: int): int =
  x + 1


let doubleFn: Fn[int, int] =
  proc(x: int): int =
    double(x)


let addOneFn: Fn[int, int] =
  proc(x: int): int =
    addOne(x)


macro inspectType(x: typed): untyped =
  echo ""
  echo "========================================"
  echo "Expression"
  echo "========================================"
  echo x.repr

  echo ""
  echo "========================================"
  echo "getType().repr"
  echo "========================================"
  echo x.getType.repr

  echo ""
  echo "========================================"
  echo "getType().treeRepr"
  echo "========================================"
  echo x.getType.treeRepr

  echo ""
  echo "========================================"
  echo "getTypeImpl().repr"
  echo "========================================"
  echo x.getTypeImpl.repr

  echo ""
  echo "========================================"
  echo "getTypeImpl().treeRepr"
  echo "========================================"
  echo x.getTypeImpl.treeRepr

  echo ""
  echo "========================================"

  result = x


proc main() =
  discard inspectType(doubleFn)

  discard inspectType(addOneFn)

  discard inspectType(
    doubleFn >>>
    addOneFn
  )


main()