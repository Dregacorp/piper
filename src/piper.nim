## piper — function composition and value piping for Nim.
##
## Public API:
##
##   >>> — left-to-right function composition
##   :>  — value-to-function application
##   Fn  — optional first-class unary closure type
##
## The implementation is compile-time oriented:
##
##   x :> a >>> b >>> c
##
## is lowered directly to:
##
##   c(b(a(x)))
##
## when possible.
##
## No public flat-composition helper is required.

import ./piper/fcompose

export fcompose