import std/unittest
import piper/fcompose


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


proc repeat2(s: string): string =
  s & s


suite "fcompose":

  test ">>> composes two int functions":
    let p =
      double >>>
      addOne

    check p(5) == 11
    check p(0) == 1
    check p(-3) == -5


  test ">>> composes in left-to-right order":
    let a =
      double >>>
      addOne

    let b =
      addOne >>>
      double

    check a(5) == 11
    check b(5) == 12


  test ">>> works across types":
    let p =
      double >>>
      toStr

    check p(5) == "10"
    check p(0) == "0"
    check p(-3) == "-6"


  test ">>> can change type on every step":
    let p =
      double >>>
      toStr >>>
      strLen

    check p(5) == 2
    check p(50) == 3
    check p(-3) == 2


  test ">>> chains three functions":
    let p =
      double >>>
      addOne >>>
      square

    check p(3) == 49
    check p(0) == 1


  test ">>> chains four functions with type change":
    let p =
      double >>>
      addOne >>>
      square >>>
      toStr

    check p(3) == "49"
    check p(5) == "121"


  test ">>> chains many functions":
    let p =
      double >>>
      addOne >>>
      double >>>
      addOne >>>
      double

    check p(0) == 6
    check p(1) == 14


  test ">>> is associative":
    let left =
      (double >>> addOne) >>>
      square

    let right =
      double >>>
      (addOne >>> square)

    check left(3) == right(3)
    check left(5) == right(5)
    check left(0) == right(0)


  test ">>> associativity holds with type changes":
    let left =
      (double >>> toStr) >>>
      strLen

    let right =
      double >>>
      (toStr >>> strLen)

    check left(5) == right(5)
    check left(50) == right(50)


  test ">>> result can be called many times":
    let p =
      double >>>
      addOne

    check p(1) == 3
    check p(2) == 5
    check p(3) == 7
    check p(100) == 201
    check p(1) == 3


  test ">>> result can be stored and reused":
    let pipeline =
      double >>>
      addOne >>>
      square

    var results: seq[int] = @[]

    for n in [1, 2, 3, 4]:
      results.add(
        pipeline(n)
      )

    check results ==
      @[
        9,
        25,
        49,
        81
      ]


  test ">>> runs nothing at construction time":
    var counter = 0

    proc trackedDouble(x: int): int =
      inc counter
      x * 2

    proc trackedAddOne(x: int): int =
      inc counter
      x + 1

    let p =
      trackedDouble >>>
      trackedAddOne

    check counter == 0

    discard p(3)
    check counter == 2

    discard p(4)
    check counter == 4


  test ">>> call order is left to right":
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

    proc third(x: int): string =
      order.add(
        "third(" &
        $x &
        ")"
      )

      $x

    let p =
      first >>>
      second >>>
      third

    discard p(5)

    check order ==
      @[
        "first(5)",
        "second(6)",
        "third(60)"
      ]


  test ">>> composes closures that capture variables":
    proc makeAdder(n: int): Fn[int, int] =
      result =
        proc(x: int): int =
          x + n

    let add5 =
      makeAdder(5)

    let add10 =
      makeAdder(10)

    let p =
      add5 >>>
      add10

    check p(0) == 15
    check p(100) == 115


  test ">>> preserves captured state across calls":
    var total = 0

    proc accumulate(x: int): int =
      total += x
      total

    proc twice(x: int): int =
      x * 2

    let p =
      accumulate >>>
      twice

    check p(5) == 10
    check p(5) == 20
    check p(5) == 30


  test "toFn converts an ordinary >>> pipeline":
    let pipeline =
      double >>>
      addOne

    let fn: Fn[int, int] =
      toFn(pipeline)

    check fn(5) == 11
    check fn(100) == 201


  test "toFn accepts an ordinary procedure":
    let fn: Fn[int, int] =
      toFn(double)

    check fn(5) == 10
    check fn(-4) == -8


  test "toFn does not double-wrap an Fn":
    let original: Fn[int, int] =
      proc(x: int): int =
        x + 5

    let converted =
      toFn(original)

    check converted(0) == 5
    check converted(100) == 105


  test "Fn values can be passed as arguments":
    proc applyTo[A, B](
        x: A,
        f: Fn[A, B]
      ): B =
      f(x)

    let p: Fn[int, int] =
      toFn(
        double >>>
        addOne
      )

    check applyTo(5, p) == 11
    check applyTo(100, p) == 201


  test "Fn values can be returned from functions":
    proc buildPipeline(): Fn[int, string] =
      toFn(
        double >>>
        addOne >>>
        toStr
      )

    let p =
      buildPipeline()

    check p(3) == "7"
    check p(5) == "11"


  test "Fn values can be stored in a sequence":
    let pipelines: seq[Fn[int, int]] =
      @[
        toFn(double >>> addOne),
        toFn(addOne >>> double),
        toFn(double >>> square)
      ]

    check pipelines[0](5) == 11
    check pipelines[1](5) == 12
    check pipelines[2](5) == 100


  test "Fn values can be composed further":
    let base =
      toFn(
        double >>>
        addOne
      )

    let squared =
      base >>>
      square

    let asStr =
      squared >>>
      toStr

    check base(3) == 7
    check squared(3) == 49
    check asStr(3) == "49"


  test ">>> with identity-like function preserves behavior":
    proc identity(x: int): int =
      x

    let p =
      double >>>
      identity >>>
      addOne

    let q =
      double >>>
      addOne

    check p(5) == q(5)
    check p(0) == q(0)


  test ">>> with int -> string -> string":
    let p =
      toStr >>>
      repeat2 >>>
      strLen

    check p(5) == 2
    check p(123) == 6


  test ">>> works on zero and negatives":
    let p =
      double >>>
      addOne >>>
      square

    check p(0) == 1
    check p(-1) == 1
    check p(-5) == 81


  test ">>> with negate":
    let p =
      double >>>
      negate >>>
      addOne

    check p(5) == -9
    check p(0) == 1
    check p(-3) == 7