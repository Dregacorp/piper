# piper/tests/config.nims
#
# 1. Adds src/ to the module search path so tests can `import piper`
#    whether run via `nimble test` or `nim c -r tests/...`.
# 2. Silences the GcUnsafe false positive that comes from composing
#    arbitrary procs with `>>>`. The operator forwards calls; if the
#    parts are gcsafe, the composition is gcsafe. Nim can't prove
#    that at the definition site, so we turn the warning off here.

import std/os

switch("path", currentSourcePath().parentDir / ".." / "src")
switch("warning", "GcUnsafe:off")