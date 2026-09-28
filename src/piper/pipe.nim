## The `:>` pipe operator.
##
## Applies a value on the left to a function on the right, immediately.
##
## `:>` binds **loosely** (OP2). This is looser than `>>>` (OP5), so
## you can mix `:>` and `>>>` in a single chain without parentheses:
##
## .. code-block:: nim
##   echo 5 :> double >>> addOne >>> square     # 121
##
## And it chains with itself:
##
## .. code-block:: nim
##   echo 5 :> double :> addOne :> square       # 121

template `:>`*(value: untyped, fn: untyped): untyped =
  ## Pipe `value` into `fn`. Runs immediately and returns the result.
  ##
  ## .. code-block:: nim
  ##   echo 5 :> double             # 10
  ##   echo 5 :> double :> addOne   # 11
  ##   echo 5 :> toStr              # "5"
  (fn)(value)