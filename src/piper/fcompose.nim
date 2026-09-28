## The `>>>` left-to-right function composition operator.
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
## The returned function is a closure because it captures the
## functions being composed.

{.push warning[GcUnsafe]: off.}

type
  Fn*[A, B] = proc(a: A): B {.closure.}
    ## A first-class closure from `A` to `B`.
    ##
    ## `Fn[A, B]` is the public type used for reusable pipelines.

proc `>>>`*[A, B, C](
    f: proc(a: A): B {.closure.},
    g: proc(b: B): C {.closure.}
  ): proc(a: A): C {.closure.} {.inline.} =
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
  ## Neither function is called while constructing the pipeline.
  ##
  ## The constructor is inlineable so the compiler can eliminate
  ## the overhead of calling the `>>>` constructor itself.
  ##
  ## The resulting function remains a closure.
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

  result = proc(a: A): C =
    g(f(a))

{.pop.}