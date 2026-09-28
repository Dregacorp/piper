[![CI](https://github.com/Dregacorp/piper/actions/workflows/ci.yml/badge.svg)](https://github.com/Dregacorp/piper/actions/workflows/ci.yml)

# piper

> Pipe and compose for Nim. Two operators, one type, one idea:
> data flows left to right.

`piper` brings the readability of Elixir's `|>`, F#'s `|>`, and
Haskell's `>>>` to Nim — in a form that lets you mix pipes and
composition freely without parentheses.

```nim
import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x

echo 5 :> double >>> addOne >>> square     # 121
```

That's the whole library: **`:>` pipes a value, `>>>` composes
functions, and the two mix naturally.**

---

## Table of contents

- [Motivation](#motivation)
- [Installation](#installation)
- [Quick start](#quick-start)
- [API reference](#api-reference)
  - [`:` — pipe a value](#-pipe-a-value)
  - [`>>>` — compose functions](#-compose-functions)
  - [`Fn[A, B]` — the function type](#fna-b--the-function-type)
- [Mixing pipes and composition](#mixing-pipes-and-composition)
- [Real-world examples](#real-world-examples)
- [Comparison with other languages](#comparison-with-other-languages)
- [Precedence: why `:>` and not `|>`](#precedence-why--and-not-)
- [Design decisions](#design-decisions)
- [Patterns and idioms](#patterns-and-idioms)
- [Common mistakes](#common-mistakes)
- [Testing](#testing)
- [Running the examples](#running-the-examples)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Motivation

### The problem: nested calls read inside-out

Consider a small transformation pipeline:

```nim
proc trim(s: string): string = s.strip
proc lower(s: string): string = s.toLowerAscii
proc split(s: string): seq[string] = s.splitWhitespace
proc join(s: seq[string]): string = s.join("-")

let result = join(split(lower(trim("  Hello World  "))))
# "hello-world"
```

You have to read it right to left and inside out to see what happens.
Even for four small functions, this is annoying. With ten, it's
unreadable.

### The fix: pipes

`piper` lets you write the same thing in the order the data flows:

```nim
let result = "  Hello World  " :> trim :> lower :> split :> join
# "hello-world"
```

Read top to bottom. The value starts on the left, each function
transforms it, and the result comes out the right.

### The second problem: repetition

Now suppose you want to reuse that pipeline on many inputs:

```nim
let result1 = "  Hello World  " :> trim :> lower :> split :> join
let result2 = "  Foo Bar  "     :> trim :> lower :> split :> join
let result3 = "  Nim Rocks  "   :> trim :> lower :> split :> join
```

Every line repeats the chain. If you want to change one step, you
change all three. That's error-prone.

### The fix: composition

`>>>` builds a **new function** from the pieces:

```nim
let slugify = trim >>> lower >>> split >>> join

let result1 = "  Hello World  " :> slugify
let result2 = "  Foo Bar  "     :> slugify
let result3 = "  Nim Rocks  "   :> slugify
```

Now the pipeline lives in one place, has a name, and can be reused,
passed around, tested, and composed further.

### The third problem: mixing

Sometimes you want both in one line. Without `piper`, mixing requires
parentheses and gets ugly fast. With `piper`, since `>>>` binds
tighter than `:>`, you just write them in order:

```nim
echo 5 :> double >>> addOne >>> square     # 121
```

No parens, no mental gymnastics. `>>>` groups the composition; `:>`
applies the value.

---

## Installation

### From Git

```bash
git clone https://github.com/Dregacorp/piper.git
cd piper
nimble install
```

### As a dependency

Add to your `.nimble` file:

```nimble
requires "piper >= 0.1.0"
```

Then:

```bash
nimble install
```

### Manual

Copy `src/piper.nim` and the `src/piper/` directory into your project
and import normally.

---

## Quick start

```nim
import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x
proc toStr(x: int): string = $x

# ----------------------------------------------------------------
# Pipe a value through functions
# ----------------------------------------------------------------

echo 5 :> double                           # 10
echo 5 :> double :> addOne                 # 11
echo 5 :> double :> addOne :> square       # 121
echo 3 :> double :> addOne :> toStr        # "7"

# ----------------------------------------------------------------
# Compose functions into a reusable pipeline
# ----------------------------------------------------------------

let mathify = double >>> addOne >>> square
echo mathify(5)                            # 121
echo mathify(10)                           # 441
echo mathify(0)                            # 1

# ----------------------------------------------------------------
# Mix the two: no parentheses needed
# ----------------------------------------------------------------

echo 5 :> double >>> addOne >>> square     # 121
```

---

## API reference

`piper` exports exactly three things. Everything else is
implementation detail.

### `:` — pipe a value

```nim
template `:>`*(value: untyped, fn: untyped): untyped
```

Takes a **value** on the left and a **function** on the right. Calls
the function immediately with the value as its argument. Returns
whatever the function returns.

```nim
5 :> double              # 10    →  double(5)
"hi" :> toUpper          # "HI"  →  toUpper("hi")
```

**Binds loosely (OP2).** This is what lets it mix with `>>>` without
parentheses. It also chains naturally with itself:

```nim
5 :> double :> addOne    # 11    →  addOne(double(5))
```

**Runs immediately.** There is no deferred evaluation. Every `:>`
executes its function right away.

**Chains left-to-right.** Each stage's output becomes the next
stage's input. Types can change at each step:

```nim
5 :> double :> toStr :> strLen   # 2
# 5  →  10  →  "10"  →  2
```

**Left side can be any expression** that produces a value:

```nim
10 :> double               # literal
x :> double                # variable
make() :> double           # function call
(3 + 4) :> double          # arithmetic
```

**Right side can be any callable:**

```nim
5 :> double                # named proc
5 :> (proc(x: int): int = x + 100)   # lambda
let n = 100
let addN = proc(x: int): int = x + n
5 :> addN                  # closure that captures `n`
```

### `>>>` — compose functions

```nim
proc `>>>`*[A, B, C](
    f: proc(a: A): B {.closure.},
    g: proc(b: B): C {.closure.}
  ): proc(a: A): C {.closure.}
```

Takes two **functions** and returns a **new function**. Does **not**
run anything.

```nim
let p = double >>> addOne
echo p(5)                  # 11
echo p(10)                 # 21
```

**Binds tighter (OP5)** than `:>`. This is what makes
`5 :> f >>> g` parse as `5 :> (f >>> g)`.

**Does nothing at build time.** The expression `f >>> g` is a
function value. It runs nothing until called. You can verify this:

```nim
var counter = 0
proc tracked(x: int): int =
  inc counter
  x * 2

let p = tracked >>> tracked      # counter == 0
discard p(5)                     # counter == 2
```

**Associative.** `(f >>> g) >>> h` and `f >>> (g >>> h)` produce the
same function.

**Result is first-class.** You can store it, pass it, return it,
put it in a collection, compose it further:

```nim
# Store in a variable
let mathify = double >>> addOne >>> square

# Store in a sequence
let pipelines: seq[Fn[int, int]] = @[
  double >>> addOne,
  double >>> square,
]

# Pass to a function
proc applyToAll(xs: seq[int], f: Fn[int, int]): seq[int] =
  for x in xs: result.add(f(x))

echo applyToAll(@[1, 2, 3], mathify)         # @[9, 25, 49]

# Return from a function
proc makeScaler(factor: int): Fn[int, int] =
  result = proc(x: int): int = x * factor

let triple = makeScaler(3)
echo 5 :> triple                             # 15

# Compose further
let base = double >>> addOne
let extended = base >>> square >>> toStr
echo extended(3)                             # "49"
```

### `Fn[A, B]` — the function type

```nim
type Fn*[A, B] = proc(a: A): B {.closure.}
```

A type alias for "a closure function from `A` to `B`." It's the type
of any composed pipeline.

```nim
let mathify: Fn[int, int] = double >>> addOne >>> square
let stringify: Fn[int, string] = double >>> addOne >>> toStr
let slugify: Fn[string, string] = trim >>> lower >>> split >>> join
```

`Fn[A, B]` is exactly equivalent to `proc(a: A): B {.closure.}`. The
alias exists to give a short name to the type that `>>>` produces and
`:>` consumes.

---

## Mixing pipes and composition

The whole reason for `piper`'s design is that `:>` and `>>>` can
appear in one chain without parentheses.

### How it parses

Since `>>>` binds tighter than `:>`:

```nim
5 :> double >>> addOne >>> square
```

groups as:

```nim
5 :> (double >>> addOne >>> square)
```

`>>>` grabs its whole right side and produces a single function.
Then `:>` applies `5` to that function.

### A full example

```nim
import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x
proc negate(x: int): int = -x

# Compose first, apply second:
echo 5 :> double >>> addOne >>> square          # 121

# Multiple pipes around composition:
echo 3 :> double >>> addOne :> square           # 49
# 3 → ((3*2)+1) = 7 → square(7) = 49

# Pipe, compose, pipe, compose:
echo 3 :> double >>> addOne :> square >>> negate    # -49

# Bound composition, applied twice:
let mathify = double >>> addOne >>> square
echo 5 :> mathify                                # 121
echo 5 :> mathify :> mathify                     # 59049
```

### The rule

> `>>>` glues functions. `:>` applies a value to one. Since `>>>`
> binds tighter, the composition happens first, then the value flows
> through it.

That's the whole design in two sentences.

---

## Real-world examples

### Example 1: text normalization

```nim
import std/strutils
import piper

proc trim(s: string): string = s.strip
proc lower(s: string): string = s.toLowerAscii
proc collapse(s: string): string = s.splitWhitespace.join(" ")

let normalize = trim >>> lower >>> collapse

echo "  Hello   World  " :> normalize
# "hello world"
```

Each piece is small and testable. The pipeline is a name. You can
apply it wherever you want.

### Example 2: number formatting

```nim
import std/strutils
import piper

proc double(x: int): int = x * 2
proc addPrefix(prefix: string): proc(s: string): string =
  result = proc(s: string): string = prefix & s

let format = double >>> intToStr >>> addPrefix("$")

echo 42 :> format                            # "$84"
```

`addPrefix` returns a closure. Composing it with other functions
works the same as composing plain procs.

### Example 3: validation pipeline

```nim
import std/strutils
import piper

proc notEmpty(s: string): string =
  if s.len == 0: raise newException(ValueError, "empty")
  s

proc maxLen(n: int): proc(s: string): string =
  result = proc(s: string): string =
    if s.len > n: raise newException(ValueError, "too long")
    s

proc isNumeric(s: string): string =
  if not s.allCharsInSet({'0'..'9'}): raise newException(ValueError, "not numeric")
  s

let validate = notEmpty >>> maxLen(10) >>> isNumeric

try:
  echo "12345" :> validate                   # "12345"
  echo "" :> validate                        # raises
except ValueError as e:
  echo "error: ", e.msg
```

The pipeline reads like a specification: "not empty, at most 10
chars, all digits."

### Example 4: reusing pipelines across a list

```nim
import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x

let mathify = double >>> addOne >>> square

let inputs = @[1, 2, 3, 4, 5]
var results: seq[int] = @[]
for x in inputs:
  results.add(x :> mathify)

echo results
# @[9, 25, 49, 81, 121]
```

### Example 5: passing pipelines to functions

```nim
import piper

proc double(x: int): int = x * 2
proc square(x: int): int = x * x
proc addOne(x: int): int = x + 1

proc applyTwice(x: int, f: Fn[int, int]): int =
  f(f(x))

echo applyTwice(3, double)             # 12   (3*2*2)
echo applyTwice(3, square)             # 81   (3^2^2 = 3^4)
echo applyTwice(3, double >>> addOne)  # 14   ((3*2)+1, then *2+1)
```

### Example 6: chaining across types

```nim
import piper

proc toStr(x: int): string = $x
proc repeat2(s: string): string = s & s
proc strLen(s: string): int = s.len

# int → string → string → int
echo 42 :> toStr :> repeat2 :> strLen
# 42 → "42" → "4242" → 4
```

The pipeline can cross type boundaries freely. Nim checks the types
at compile time, so a mismatch is caught before you run anything.

### Example 7: building different pipelines from the same pieces

```nim
import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1
proc square(x: int): int = x * x
proc negate(x: int): int = -x

# Same pieces, different pipelines:
let a = double >>> addOne                     # 2x + 1
let b = addOne >>> double                     # 2(x + 1)
let c = double >>> square                     # (2x)^2
let d = square >>> double                     # 2(x^2)
let e = double >>> addOne >>> negate          # -(2x + 1)

echo 5 :> a                                   # 11
echo 5 :> b                                   # 12
echo 5 :> c                                   # 100
echo 5 :> d                                   # 50
echo 5 :> e                                   # -11
```

Each pipeline is a value. You can compare them, store them, choose
between them at runtime.

### Example 8: runtime pipeline selection

```nim
import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1

let pipelines: seq[Fn[int, int]] = @[
  double >>> addOne,
  addOne >>> double,
  double >>> double,
]

for i, p in pipelines:
  echo "pipeline ", i, " on 5: ", (5 :> p)

# pipeline 0 on 5: 11
# pipeline 1 on 5: 12
# pipeline 2 on 5: 20
```

---

## Comparison with other languages

### Elixir

Elixir's `|>` is pure application, no composition:

```elixir
result = 5 |> double() |> addOne() |> square()
```

To reuse the pipeline, you wrap it in a function:

```elixir
mathify = fn x -> x |> double() |> addOne() |> square() end
mathify.(5)
```

In `piper`, `>>>` gives you the reusable pipeline directly:

```nim
let mathify = double >>> addOne >>> square
echo 5 :> mathify
```

### F#

F# has both `|>` (application) and `>>` (composition):

```fsharp
let mathify = double >> addOne >> square
let result = 5 |> mathify
```

But F# keeps them at different precedences so you can't mix
`5 |> double >> addOne` in one line without parens. `piper` uses
`:>` and `>>>` so that mixing works.

### Haskell

Haskell's `.` is composition (right-to-left) and `>>>` is
left-to-right composition from `Control.Category`. Application is
`$` or just juxtaposition:

```haskell
mathify = double >>> addOne >>> square
result = mathify 5
```

`piper`'s `>>>` matches Haskell's, but `:>` plays the role of `$`
(both apply a value), and `>>>` binds tighter than `:>` so they mix.

### A comparison table

| Language        | Apply            | Compose           | Mix without parens |
| --------------- | ---------------- | ----------------- | ------------------ |
| Elixir          | `\|>`           | (wrap in fn)      | n/a                |
| F#              | `\|>`           | `>>`            | No                 |
| Haskell         | `$`, space     | `.`, `>>>`    | Partial (`.`)    |
| OCaml           | `\|>`           | `@@`            | No                 |
| **piper** | **`:>`** | **`>>>`** | **Yes**      |

---

## Precedence: why `:>` and not `|>`

Nim computes operator precedence from the **first character** of the
operator. This is not something a library can override.

| First char              | Level | Meaning        |
| ----------------------- | ----- | -------------- |
| `$` `^`             | 10    | highest        |
| `*` `/` `\` `%` | 9     | multiplicative |
| `+` `-` `~` `\|` | 8     | additive       |
| `&`                   | 7     |                |
| `.`                   | 6     |                |
| `=` `<` `>` `!` | 5     | comparison     |
| `and`                 | 4     |                |
| `or` `xor`          | 3     |                |
| `@` `:` `?`       | 2     | lowest binary  |

- `|>` starts with `|`, level **8**. Too tight. It grabs
  `5 |> double` before `>>>` can grab `double >>> addOne`.
- `:>` starts with `:`, level **2**. Looser than `>>>` (level 5).
  `>>>` groups first, then `:>` applies.

Given the restriction, `:>` is one of the few short symbols that
work. Other options considered:

| Symbol  | Level | Works | Notes                        |
| ------- | ----- | ----- | ---------------------------- |
| `\|>`  | 8     | ❌    | Too tight                    |
| `\|>>` | 8     | ❌    | Same                         |
| `:>`  | 2     | ✅    | Readable                     |
| `::>` | 2     | ✅    | Uglier                       |
| `?>`  | 2     | ✅    | Reads as "maybe," not "pipe" |
| `->`  | 0     | ✅    | Conflicts with`std/sugar`  |
| `@>`  | 2     | ✅    | Confusing next to`@[...]`  |

`:>` was chosen for being short, easy to type, and clear.

**The rule:** put `:` between a value and a pipeline, `>` between
functions.

---

## Design decisions

### Why two operators instead of one?

You could overload `>>>` to mean "apply if left is a value, compose
if left is a function." Some libraries do this. It was rejected here
because:

1. **Ambiguity for readers.** `f >>> g` doesn't tell you whether `f`
   is a function being composed or a value being applied. You have
   to know the types.
2. **Two concepts, two symbols.** "Apply" and "compose" are different
   operations. Giving them different symbols makes code clearer.
3. **No precedent.** No mainstream functional language overloads the
   composition operator to also apply.

The two-symbol design keeps each operator doing one thing.

### Why does `>>>` need `{.closure.}`?

Without it, `proc(a: A): B` is a **function pointer** — just an
address, like in C. Function pointers can't capture variables from
their surroundings. `>>>` needs closures because the returned
function captures `f` and `g`.

### Why is `:>` a template and not a proc?

A template expands at compile time into `fn(value)`. Zero runtime
overhead, no intermediate values, works with any expression on the
left.

If `:>` were a proc, it would need a specific signature, forcing
types on the caller. The template approach is more flexible.

### Why no `|>`?

`:>` covers the same job with better precedence for mixing. Having
both would duplicate functionality and confuse which to use.

### Why no assignment variant of `:>`?

It was considered and rejected. Making `x :> c` do "assign to `c`"
if `c` is a variable, and "call `c`" if `c` is a function, conflates
two unrelated operations. It would break the reader's ability to
tell what a line does without knowing types, and it breaks
composition (an assign step returns nothing useful). Use `let` or
`var` for assignment, as every language does.

---

## Patterns and idioms

### Bind early, apply often

```nim
let slugify = trim >>> lower >>> split >>> join

for s in inputs:
  echo s :> slugify
```

Compose once, apply many times. This is the primary use of `>>>`.

### Store pipelines in collections

```nim
let pipelines: seq[Fn[int, int]] = @[
  double >>> addOne,
  double >>> square,
  addOne >>> double,
]
```

You can index, iterate, and dispatch on them.

### Return pipelines from functions

```nim
proc makeScaler(factor: int): Fn[int, int] =
  proc(x: int): int = x * factor

let triple   = makeScaler(3)
let timesTen = makeScaler(10)

echo 5 :> triple                       # 15
echo 5 :> timesTen                     # 50
```

`>>>` and closures work together naturally.

### Compose partial pipelines

```nim
let parse   = trim >>> lower
let split   = (s: string) => s.splitWhitespace
let join    = (xs: seq[string]) => xs.join("-")

let slugify = parse >>> split >>> join
```

Each stage is named. Change one, the whole pipeline updates.

### Mix `:>` and `>>>` when it reads best

```nim
# All pipes — simplest
echo 5 :> double :> addOne :> square

# Piped into a named composition
echo 5 :> mathify

# Composition inline, piped
echo 5 :> double >>> addOne >>> square
```

Any of these is correct. Pick the one that reads clearest in context.

---

## Common mistakes

### `:> b` where `b` is a value, not a function

```nim
let b = 5
5 :> b         # ERROR: attempting to call routine: 'b'
```

The right side of `:>` must be **callable**. To store the result,
use `let`:

```nim
let c = 5 :> double
```

### Expecting `>>>` to run something

```nim
let p = double >>> addOne
# Nothing has run yet. p is a function.
echo p(5)                          # 11 — now it runs
```

`>>>` builds a function. It doesn't call it.

### Expecting `:>` to assign

```nim
var c: int
5 :> c         # ERROR: 'c' is not callable
```

Use `let`/`var` for assignment:

```nim
var c: int
c = 5 :> double
```

### Forgetting that `|>` doesn't exist

If you copy examples from Elixir or F#, replace `|>` with `:>`:

```nim
# Elixir style:
# 5 |> double |> addOne

# Nim with piper:
5 :> double :> addOne
```

### Mixing with `->`

Nim's `std/sugar` uses `->` for procedure types. If you import
`std/sugar` in the same file, don't define `->` as a pipe. Use `:>`.

---

## Testing

```bash
nimble test
```

This runs four suites:

| Suite                 | Tests | Covers                |
| --------------------- | ----- | --------------------- |
| `piper`             | 8     | integration tests     |
| `fcompose`          | 23    | `>>>` composition   |
| `pipe`              | 30    | `:>` application    |
| `mixing :> and >>>` | 10    | precedence and mixing |

**Total: 71 tests.**

The test files live in `tests/`:

- `tests/test1.nim` — integration
- `tests/test_fcompose.nim` — `>>>` unit tests
- `tests/test_pipe.nim` — `:>` unit tests
- `tests/test_mixing.nim` — precedence and mixing

To run a single suite:

```bash
nim c -r tests/test_mixing.nim
```

---

## Running the examples

Three complete demos live in `examples/`:

| File                               | What it shows                           |
| ---------------------------------- | --------------------------------------- |
| `examples/demo.nim`              | Every feature in one file, 10 sections  |
| `examples/mixing.nim`            | `:>` and `>>>` mixed without parens |
| `examples/compose_and_apply.nim` | Build super functions, pass them around |

Run any of them directly:

```bash
nim c -r examples/demo.nim
```

Or via nimble tasks:

```bash
nimble demo
nimble mixing
nimble compose_apply
```

---

## FAQ

**Q: Why `:>` and not `|>`?**

Because `|>` binds too tightly in Nim (level 8). It would prevent
mixing with `>>>` (level 5) without parentheses. `:>` is level 2, so
it mixes cleanly.

**Q: Can I have `|>` too?**

You could add it back, but it duplicates `:>` and creates confusion
about which to use. `:>` handles both cases.

**Q: What's the difference between `:>` and `>>>` in one sentence?**

`:>` calls a function. `>>>` builds a function. `:>` runs now.
`>>>` runs later (when you call the result).

**Q: Does `>>>` run anything when I write `f >>> g`?**

No. `f >>> g` is a function value. Nothing runs until you call it.

**Q: Can I use this with `async`?**

Not tested. `piper` works with synchronous functions. For async
pipelines, you'd need an async-aware operator.

**Q: Does `:>` work with varargs or method call syntax?**

Only with functions that take a single argument. `:>` is designed
for single-argument transformations.

**Q: Is `Fn[A, B]` different from `proc(a: A): B {.closure.}`?**

No. `Fn[A, B]` is exactly a type alias for
`proc(a: A): B {.closure.}`. Use whichever is clearer.

**Q: Why does `>>>` have `{.gcsafe.}` warning disabled?**

Because `>>>` just forwards calls to `f` and `g`. Whether they are
gcsafe cannot be known at the definition site. Nim conservatively
warns. The library suppresses the warning in its own module and
provides a config in `tests/` and `examples/` to suppress it there.
If you want strict gcsafe checking, add `{.push warning[GcUnsafe]: on.}`
in your own code.

**Q: Can I store different pipelines in the same sequence?**

Yes, if they have the same type signature:

```nim
let pipelines: seq[Fn[int, int]] = @[
  double >>> addOne,
  double >>> square,
]
```

For mixed signatures, use a sum type or a base type.

**Q: Does `:>` short-circuit anything?**

No. `:>` is plain application. Each stage runs unconditionally.
For conditional pipelines, use `Option` types and appropriate
functions.

---

## Contributing

Bug reports, feature ideas, and pull requests are welcome.

### Setup

```bash
git clone https://github.com/Dregacorp/piper.git
cd piper
nimble test
```

### Guidelines

- Add tests for any new behavior.
- Keep the public API surface small.
- Prefer clarity over cleverness.
- Update the README if you change the API.

### Reporting bugs

Include:

- Nim version (`nim --version`)
- The exact code that fails
- The full error message
- Expected vs actual behavior

---

## Versioning

`piper` follows [semantic versioning](https://semver.org/):

- **Major** — breaking API changes
- **Minor** — new features, backward compatible
- **Patch** — bug fixes, backward compatible

### Changelog

**0.1.0** — Initial release

- `:>` pipe operator
- `>>>` composition operator
- `Fn[A, B]` type alias
- Tests for both operators and their mixing

---

## License

BSD-3-Clause. See [LICENSE](LICENSE) for details.

---

## See also

- [Nim manual — operators](https://nim-lang.org/docs/manual.html#syntax-operators)
- [Nim manual — templates](https://nim-lang.org/docs/manual.html#templates)
- [Elixir pipe operator](<https://hexdocs.pm/elixir/Kernel.html#%7C%3E/2>)
- [F# pipe and composition](https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/symbol-and-operator-reference/)
- [Haskell Control.Category](https://hackage.haskell.org/package/base/docs/Control-Category.html)

---

<p align="center">
  <sub>Built with Nim. Pipe on.</sub>
</p>
