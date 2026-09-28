## The `>>>` left-to-right function composition operator.
##
## `>>>` builds a **new function**. It does **not** run anything.
## You call the result later, once or many times.
##
## .. code-block:: nim
##   let pipeline = double >>> addOne >>> square
##   echo pipeline(3)   # runs double, then addOne, then square
##   echo pipeline(5)   # runs them again with 5

{.push warning[GcUnsafe]: off.}

type
  Fn*[A, B] = proc(a: A): B {.closure.}
    ## A closure function from `A` to `B`.
    ##
    ## Exported so users can name the type of a composed pipeline:
    ##
    ## .. code-block:: nim
    ##   let p: Fn[int, string] = double >>> toStr

proc `>>>`*[A, B, C](
    f: proc(a: A): B {.closure.},
    g: proc(b: B): C {.closure.}
  ): proc(a: A): C {.closure.} =
  ## Compose `f` and `g` into a single function.
  ##
  ## Runs `f` first, then `g`. Returns the result of `g`.
  ##
  ## Nothing runs when you write `f >>> g`. The result is a new
  ## function that you call later.
  ##
  ## .. code-block:: nim
  ##   let p = double >>> addOne
  ##   echo p(5)      # 11
  ##   echo p(100)    # 201
  ##
  ## Composition is associative: `(f >>> g) >>> h` and
  ## `f >>> (g >>> h)` behave the same way.
  result = proc(a: A): C = g(f(a))

{.pop.}