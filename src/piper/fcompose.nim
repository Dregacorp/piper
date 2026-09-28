## Left-to-right function composition for Nim.
##
## `>>>` composes two unary functions into a new unary function.
##
## Example:
##
## .. code-block:: nim
##   import piper
##
##   proc double(x: int): int =
##     x * 2
##
##   proc addOne(x: int): int =
##     x + 1
##
##   proc square(x: int): int =
##     x * x
##
##   let pipeline =
##     double >>> addOne >>> square
##
##   echo pipeline(5)
##   # 121
##
## `>>>` returns a closure because the composed function captures
## the two functions being composed.

{.push warning[GcUnsafe]: off.}

type
  Fn*[A, B] = proc(a: A): B {.closure.}
    ## A first-class closure from `A` to `B`.
    ##
    ## `Fn[A, B]` is the public type used for reusable pipelines.


proc `>>>`*[A, B, C](
    f: Fn[A, B],
    g: Fn[B, C]
  ): Fn[A, C] {.inline.} =
  ## Compose `f` and `g` left-to-right.
  ##
  ## Given:
  ##
  ##   f : A -> B
  ##   g : B -> C
  ##
  ## the result is:
  ##
  ##   A -> C
  ##
  ## Evaluation order is:
  ##
  ##   x -> f(x) -> g(result)
  ##
  ## The composition is lazy with respect to execution:
  ## neither function is called while constructing the pipeline.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##   let pipeline = double >>> addOne
  ##
  ##   # Nothing has run here.
  ##
  ##   let value = pipeline(5)
  ##   # double(5) runs first.
  ##   # addOne(10) runs second.
  ##
  result = proc(a: A): C =
    g(f(a))


{.pop.}