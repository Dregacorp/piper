# piper/examples/config.nims
#
# Adds src/ to the module search path so examples can `import piper`.
# Also silences the GcUnsafe false positive that comes from `>>>`.

import std/os

switch("path", currentSourcePath().parentDir / ".." / "src")
switch("warning", "GcUnsafe:off")