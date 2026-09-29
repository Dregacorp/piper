## Compatibility module for piper's pipe API.
##
## The public implementation of `:>` lives in fcompose.nim so that
## `:>` and `>>>` can share the same compile-time AST machinery.
##
## Existing code using:
##
##   import piper/pipe
##
## continues to work.

import ./fcompose

export fcompose