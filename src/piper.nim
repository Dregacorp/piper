## piper — function composition and piping for Nim.
##
## Two operators:
##
## - `:>` — pipe a value through a function. Runs immediately.
##   Binds loosely (OP2), so it can mix with `>>>` without parentheses.
## - `>>>` — compose two functions into a new one. Runs nothing until
##   the composed function is called. Binds at OP5.
##
## Plus the `Fn[A, B]` type for naming composed functions.
##
## .. code-block:: nim
##   import piper
##
##   proc double(x: int): int = x * 2
##   proc addOne(x: int): int = x + 1
##   proc square(x: int): int = x * x
##
##   # Pipe a value through functions:
##   echo 5 :> double :> addOne :> square             # 121
##
##   # Build a reusable composed function:
##   let mathify = double >>> addOne >>> square
##   echo mathify(5)                                  # 121
##
##   # Mix pipe and composition (no parens needed):
##   echo 5 :> double >>> addOne >>> square           # 121
##   echo 3 :> double >>> addOne :> square            # 49

import ./piper/pipe
import ./piper/fcompose

export pipe
export fcompose