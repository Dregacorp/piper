# Package

version       = "0.1.0"
author        = "Dregacorp"
description   = "Pipe and compose for Nim: :> applies a value to a function, >>> composes functions."
license       = "BSD-3-Clause"
srcDir        = "src"
installExt    = @["nim"]

# Dependencies

requires "nim >= 2.2.12"

task test, "Run the test suite":
  exec "nim c -r tests/test1.nim"
  exec "nim c -r tests/test_fcompose.nim"
  exec "nim c -r tests/test_pipe.nim"
  exec "nim c -r tests/test_mixing.nim"

task demo, "Run the demo":
  exec "nim c -r examples/demo.nim"

task mixing, "Run the mixing demo":
  exec "nim c -r examples/mixing.nim"

task compose_apply, "Run the compose-and-apply demo":
  exec "nim c -r examples/compose_and_apply.nim"