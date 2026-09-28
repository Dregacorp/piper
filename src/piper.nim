## piper — function composition and piping for Nim.
##
## Public operators:
##
## - `:>`  — immediately applies a value to a unary function.
## - `>>>` — composes two unary functions into a new function.
##
## Public type:
##
## - `Fn[A, B]` — first-class unary closure type.
##
## Public optimization:
##
## - `flatCompose` — compile-time flat composition that avoids
##   nested composition closures.

import ./piper/pipe
import ./piper/fcompose

export pipe
export fcompose