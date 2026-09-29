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

That's the core of the library: **`:>` pipes a value, `>>>` composes
functions, and the two mix naturally.** `Fn[A, B]` and `toFn` provide an
explicit first-class closure representation when you need one.

---

## Table of contents

* [Motivation](#motivation)
* [Installation](#installation)
* [Quick start](#quick-start)
* [API reference](#api-reference)

  * [`:>` — pipe a value](#-pipe-a-value)
  * [`>>>` — compose functions](#-compose-functions)
  * [`Fn[A, B]` — the function type](#fna-b--the-function-type)
  * [`toFn` — convert to a first-class function](#tofn--convert-to-a-first-class-function)
* [Mixing pipes and composition](#mixing-pipes-and-composition)
* [Real-world examples](#real-world-examples)
* [Comparison with other languages](#comparison-with-other-languages)
* [Precedence: why `:>` and not `|>`](#precedence-why--and-not-)
* [Design decisions](#design-decisions)
* [Patterns and idioms](#patterns-and-idioms)
* [Common mistakes](#common-mistakes)
* [Testing](#testing)
* [Running the examples](#running-the-examples)
* [Benchmark](#benchmark)
* [FAQ](#faq)
* [Contributing](#contributing)
* [License](#license)

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

`piper` exposes four public API symbols:

```text
:>
>>>
Fn[A, B]
toFn
```

Everything else is implementation detail.

### `:>` — pipe a value

```nim
macro `:>`*(value: typed, stage: untyped): untyped
```

Takes a **value** on the left and a **callable expression** on the
right. The macro lowers the expression directly to function
application.

```nim
5 :> double              # 10    →  double(5)
"hi" :> toUpper          # "HI"  →  toUpper("hi")
```

**Binds loosely (OP2).** This is what lets it mix with `>>>` without
parentheses. It also chains naturally with itself:

```nim
5 :> double :> addOne    # 11    →  addOne(double(5))
```

**Runs immediately.** There is no deferred pipeline object. The
generated expression calls the function during normal evaluation.

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

**Right side can be any callable expression accepted by Nim:**

```nim
5 :> double                # named proc
5 :> (proc(x: int): int = x + 100)   # lambda

let n = 100
let addN = proc(x: int): int = x + n

5 :> addN                  # closure that captures `n`
```

### `>>>` — compose functions

```nim
macro `>>>`*(lhs: untyped, rhs: untyped): untyped
```

Takes two **function expressions** and generates a new callable.
Does **not** run anything when the composition is created.

```nim
let p = double >>> addOne
echo p(5)                  # 11
echo p(10)                 # 21
```

**Binds tighter (OP5)** than `:>`. This is what makes

```nim
5 :> f >>> g
```

parse as:

```nim
5 :> (f >>> g)
```

**Does nothing at build time.** The expression `f >>> g` is a
function value. It runs only when the resulting callable is invoked.

You can verify this:

```nim
var counter = 0

proc tracked(x: int): int =
  inc counter
  x * 2

let p = tracked >>> tracked      # counter == 0
discard p(5)                     # counter == 2
```

**Associative.** `(f >>> g) >>> h` and `f >>> (g >>> h)` represent the
same left-to-right function composition.

**First-class when needed.** A direct `>>>` pipeline can remain an
ordinary `nimcall` procedure when all stages are ordinary direct
procedures. When you need the stable first-class `Fn[A, B]` closure
type, use `toFn`.

```nim
let mathify =
  double >>>
  addOne >>>
  square

let firstClass: Fn[int, int] =
  toFn(mathify)

echo firstClass(5)            # 121
```

You can then store the `Fn` value, pass it to another function, return
it, put it in a collection, or compose it further:

```nim
let mathify =
  toFn(
    double >>>
    addOne >>>
    square
  )

# Store in a sequence
let pipelines: seq[Fn[int, int]] =
  @[
    toFn(double >>> addOne),
    toFn(double >>> square),
  ]

# Pass to a function
proc applyToAll(
    xs: seq[int],
    f: Fn[int, int]
  ): seq[int] =
  for x in xs:
    result.add(f(x))

echo applyToAll(@[1, 2, 3], mathify)
# @[9, 25, 49]

# Return from a function
proc makeScaler(factor: int): Fn[int, int] =
  result =
    proc(x: int): int =
      x * factor

let triple =
  makeScaler(3)

echo 5 :> triple             # 15

# Compose further
let base =
  toFn(
    double >>>
    addOne
  )

let extended =
  base >>>
  square >>>
  toStr

echo extended(3)             # "49"
```

### `Fn[A, B]` — the function type

```nim
type Fn*[A, B] = proc(a: A): B {.closure.}
```

`Fn[A, B]` is a first-class closure type representing a unary function
from `A` to `B`.

A composed pipeline made entirely from ordinary direct procedures may
be generated as a `nimcall` procedure rather than a closure. `toFn`
provides the explicit conversion when a `Fn[A, B]` value is required.

```nim
let mathify: Fn[int, int] =
  toFn(
    double >>>
    addOne >>>
    square
  )

let stringify: Fn[int, string] =
  toFn(
    double >>>
    addOne >>>
    toStr
  )

let slugify: Fn[string, string] =
  toFn(
    trim >>>
    lower >>>
    split >>>
    join
  )
```

The `Fn` type is equivalent to:

```nim
proc(a: A): B {.closure.}
```

Use `Fn[A, B]` when an explicit first-class closure type makes the
interface clearer.

### `toFn` — convert to a first-class function

`toFn` converts an ordinary `nimcall` procedure or generated
non-closure pipeline into the first-class `Fn[A, B]` closure type.

The public overloads are:

```nim
proc toFn*[A, B](
    value: proc(a: A): B {.nimcall.}
  ): Fn[A, B] {.inline.}

proc toFn*[A, B](
    value: Fn[A, B]
  ): Fn[A, B] {.inline.}
```

For a direct procedure:

```nim
let doubleFn: Fn[int, int] =
  toFn(double)

echo doubleFn(5)              # 10
```

For a composed pipeline:

```nim
let mathify: Fn[int, int] =
  toFn(
    double >>>
    addOne >>>
    square
  )

echo mathify(5)               # 121
```

An existing `Fn` value is not unnecessarily wrapped again:

```nim
let original: Fn[int, int] =
  proc(x: int): int =
    x + 5

let converted =
  toFn(original)

echo converted(10)            # 15
```

`toFn` is the explicit boundary between the library's efficient
direct-call representation and its first-class closure representation.

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

`>>>` grabs its whole right side and produces a single callable.
Then `:>` applies `5` to that callable.

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
echo 3 :> double >>> addOne :> square >>> negate # -49

# Bound composition, applied twice:
let mathify =
  double >>>
  addOne >>>
  square

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

let normalize =
  trim >>>
  lower >>>
  collapse

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

proc addPrefix(
    prefix: string
  ): proc(s: string): string =
  result =
    proc(s: string): string =
      prefix & s

let format =
  double >>>
  intToStr >>>
  addPrefix("$")

echo 42 :> format                            # "$84"
```

`addPrefix` returns a closure. Composing it with other functions
works the same as composing plain procs.

### Example 3: validation pipeline

```nim
import std/strutils
import piper

proc notEmpty(s: string): string =
  if s.len == 0:
    raise newException(ValueError, "empty")
  s

proc maxLen(n: int): proc(s: string): string =
  result =
    proc(s: string): string =
      if s.len > n:
        raise newException(ValueError, "too long")
      s

proc isNumeric(s: string): string =
  if not s.allCharsInSet({'0'..'9'}):
    raise newException(ValueError, "not numeric")
  s

let validate =
  notEmpty >>>
  maxLen(10) >>>
  isNumeric

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

let mathify =
  double >>>
  addOne >>>
  square

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

proc applyTwice(
    x: int,
    f: Fn[int, int]
  ): int =
  f(f(x))

echo applyTwice(3, toFn(double))             # 12   (3*2*2)
echo applyTwice(3, toFn(square))             # 81   (3^2^2 = 3^4)
echo applyTwice(
  3,
  toFn(double >>> addOne)
)                                             # 15
# First: 3 → 7
# Second: 7 → 15
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

Each pipeline is a value. You can store them, select between them,
dispatch on them at runtime, and compose them further.

### Example 8: runtime pipeline selection

```nim
import piper

proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1

let pipelines: seq[Fn[int, int]] =
  @[
    toFn(double >>> addOne),
    toFn(addOne >>> double),
    toFn(double >>> double),
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

Elixir's `|>` is application, not function composition:

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
let mathify =
  double >>>
  addOne >>>
  square

echo 5 :> mathify
```

### F#

F# has both `|>` for application and `>>` for left-to-right function
composition:

```fsharp
let mathify = double >> addOne >> square
let result = 5 |> mathify
```

The operators represent different operations. `piper` uses `:>` and
`>>>` with deliberately chosen precedence so value application and
function composition can appear in the same expression without
parentheses.

### Haskell

Haskell's `.` is composition (right-to-left) and `>>>` is
left-to-right composition from `Control.Category`. Application is
`$` or ordinary function application:

```haskell
mathify = double >>> addOne >>> square
result = mathify 5
```

`piper`'s `>>>` matches Haskell's left-to-right composition, but `:>`
is a left-to-right value-application operator rather than Haskell's
right-hand-side `$`.

### OCaml

OCaml provides `|>` for left-to-right value application and
`Fun.compose` for function composition:

```ocaml
let mathify =
  Fun.compose
    square
    (Fun.compose addOne double)

let result = 5 |> mathify
```

`@@` is an application operator, not a function-composition operator.

### A comparison table

| Language  | Apply            | Compose       | Mix without parens  |
| --------- | ---------------- | ------------- | ------------------- |
| Elixir    | `\|>`            | (wrap in fn)  | n/a                 |
| F#        | `\|>`            | `>>`          | Different syntax    |
| Haskell   | `$`, application | `.`, `>>>`    | Different direction |
| OCaml     | `\|>`            | `Fun.compose` | No                  |
| **piper** | **`:>`**         | **`>>>`**     | **Yes**             |

---

## Precedence: why `:>` and not `|>`

Nim computes operator precedence from the **first character** of the
operator. This is not something a library can override.

| First char       | Level | Meaning        |
| ---------------- | ----- | -------------- |
| `$` `^`          | 10    | highest        |
| `*` `/` `\` `%`  | 9     | multiplicative |
| `+` `-` `~` `\|` | 8     | additive       |
| `&`              | 7     |                |
| `.`              | 6     |                |
| `=` `<` `>` `!`  | 5     | comparison     |
| `and`            | 4     |                |
| `or` `xor`       | 3     |                |
| `@` `:` `?`      | 2     | lowest binary  |

* `|>` starts with `|`, level **8**. Too tight. It grabs
  `5 |> double` before `>>>` can grab `double >>> addOne`.
* `:>` starts with `:`, level **2**. Looser than `>>>` (level 5).
  `>>>` groups first, then `:>` applies.

Given the restriction, `:>` is one of the few short symbols that
work. Other options considered:

| Symbol | Level | Works | Notes                        |
| ------ | ----- | ----- | ---------------------------- |
| `\|>`  | 8     | ❌     | Too tight                    |
| `\|>>` | 8     | ❌     | Same                         |
| `:>`   | 2     | ✅     | Readable                     |
| `::>`  | 2     | ✅     | Uglier                       |
| `?>`   | 2     | ✅     | Reads as "maybe," not "pipe" |
| `->`   | 0     | ✅     | Conflicts with `std/sugar`   |
| `@>`   | 2     | ✅     | Confusing next to `@[...]`   |

`:>` was chosen for being short, easy to type, and clear.

**The rule:** put `:` between a value and a pipeline, `>` between
functions.

---

## Design decisions

### Why two operators instead of one?

You could overload `>>>` to mean "apply if the left side is a value,
compose if the left side is a function." Some libraries do this. It
was rejected here because:

1. **Ambiguity for readers.** `f >>> g` doesn't tell you whether `f`
   is a function being composed or a value being applied. You have
   to know the types.
2. **Two concepts, two symbols.** "Apply" and "compose" are different
   operations. Giving them different symbols makes code clearer.
3. **No overloaded semantic role.** Keeping `>>>` as composition and
   `:>` as application means each operator has one meaning.

The two-symbol design keeps each operator doing one thing.

### Why does `>>>` sometimes generate `{.closure.}`?

The implementation distinguishes between direct procedures and
dynamic or closure-valued stages.

When all stages are ordinary direct procedures, `>>>` can generate an
ordinary `nimcall` procedure without a closure environment.

When a stage requires a closure or a dynamic value, `>>>` generates a
closure instead.

For example:

```nim
proc double(x: int): int = x * 2
proc addOne(x: int): int = x + 1

let direct =
  double >>>
  addOne
```

can use a direct `nimcall` representation.

A closure stage requires a closure representation:

```nim
let n = 10

let addN =
  proc(x: int): int =
    x + n

let pipeline =
  double >>>
  addN
```

The distinction avoids forcing every pipeline through a closure
representation when one is not required.

### Why is `:>` a macro and not a proc?

`:>` is implemented as a compile-time macro so it can transform the
source expression directly into ordinary function application.

For example:

```nim
5 :> double >>> addOne >>> square
```

is lowered to the equivalent nested application:

```nim
square(addOne(double(5)))
```

This avoids requiring a runtime pipe object or generic application
helper and lets the macro handle the syntactic composition structure.

A normal procedure would not provide the same AST-level control over
the expression.

### Why is `>>>` a macro and not a proc?

`>>>` is also implemented as a compile-time macro so chained
composition can be flattened before code generation.

```nim
a >>> b >>> c >>> d
```

is treated as one composition sequence rather than repeatedly
constructing intermediate composition objects.

This lets the implementation choose the appropriate generated
representation:

```text
all direct procedures
        ↓
ordinary nimcall procedure

dynamic/closure stages
        ↓
closure procedure
```

### Why no `|>`?

`:>` covers the same value-to-function application role with
precedence specifically chosen for mixing with `>>>`.

Having both would duplicate functionality and create two ways to write
the same operation.

### Why no assignment variant of `:>`?

It was considered and rejected. Making `x :> c` do "assign to `c`"
if `c` is a variable, and "call `c`" if `c` is a function, conflates
two unrelated operations. It would break the reader's ability to
tell what a line does without knowing types, and it breaks
composition because an assignment step does not provide a useful
callable result.

Use `let` or `var` for assignment, as normal Nim code does.

---

## Patterns and idioms

### Bind early, apply often

```nim
let slugify =
  trim >>>
  lower >>>
  split >>>
  join

for s in inputs:
  echo s :> slugify
```

Compose once, apply many times. This is the primary use of `>>>`.

### Store pipelines in collections

When a collection needs an explicit first-class function type, convert
the pipelines with `toFn`:

```nim
let pipelines: seq[Fn[int, int]] =
  @[
    toFn(double >>> addOne),
    toFn(double >>> square),
    toFn(addOne >>> double),
  ]
```

You can index, iterate, select, and dispatch on them.

### Return pipelines from functions

```nim
proc makeScaler(factor: int): Fn[int, int] =
  proc(x: int): int =
    x * factor

let triple =
  makeScaler(3)

let timesTen =
  makeScaler(10)

echo 5 :> triple                       # 15
echo 5 :> timesTen                     # 50
```

`>>>` and closures work together naturally.

### Compose partial pipelines

```nim
let parse =
  trim >>>
  lower

let split =
  (s: string) =>
    s.splitWhitespace

let join =
  (xs: seq[string]) =>
    xs.join("-")

let slugify =
  parse >>>
  split >>>
  join
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
let c =
  5 :> double
```

### Expecting `>>>` to run something

```nim
let p =
  double >>>
  addOne

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
c =
  5 :> double
```

### Expecting every `>>>` result to be an `Fn`

A direct pipeline may be generated as an ordinary `nimcall` procedure:

```nim
let pipeline =
  double >>>
  addOne
```

When an explicit `Fn` value is required, use `toFn`:

```nim
let pipeline: Fn[int, int] =
  toFn(
    double >>>
    addOne
  )
```

### Forgetting that `|>` doesn't exist

If you copy examples from Elixir, F#, or OCaml, replace `|>` with
`:>`:

```nim
# Elixir/F#/OCaml style:
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

| Suite               | Tests | Covers                |
| ------------------- | ----- | --------------------- |
| `piper`             | 8     | integration tests     |
| `fcompose`          | 23    | `>>>` composition     |
| `pipe`              | 30    | `:>` application      |
| `mixing :> and >>>` | 10    | precedence and mixing |

**Total: 71 tests.**

The test files live in `tests/`:

* `tests/test1.nim` — integration
* `tests/test_fcompose.nim` — `>>>` unit tests
* `tests/test_pipe.nim` — `:>` unit tests
* `tests/test_mixing.nim` — precedence and mixing

To run a single suite:

```bash
nim c -r tests/test_mixing.nim
```

---

## Running the examples

Three complete demos live in `examples/`:

| File                             | What it shows                           |
| -------------------------------- | --------------------------------------- |
| `examples/demo.nim`              | Every feature in one file, 10 sections  |
| `examples/mixing.nim`            | `:>` and `>>>` mixed without parens     |
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

## Benchmark

`piper` was benchmarked against equivalent pipe/application and
composition patterns in Nim, Haskell, Elixir, F#, and OCaml.

The benchmark measures three pipeline shapes:

* direct nested calls
* native pipe/application syntax
* function composition

Each case executes **3,000,000 complete pipeline iterations** and
uses **9 measured samples**, reporting the median.

### Benchmark environment

| Toolchain           | Version                |
| ------------------- | ---------------------- |
| Nim                 | 2.2.12                 |
| Haskell / GHC       | 9.10.3                 |
| Elixir / Erlang/OTP | Elixir 1.20.4 / OTP 29 |
| F# / .NET           | .NET 10.0.12           |
| OCaml               | 5.3.0                  |

The benchmark sources are in `bench/comparative/`.

Run the complete comparison with:

```bash
python3 bench/comparative/run_all.py
```

Results are also written to:

```text
bench/comparative/results/latest.csv
bench/comparative/results/latest.md
```

### Results

Lower `ns/op` means less time per complete pipeline execution.

| Language | Stage | Direct ns/op | Pipe ns/op | Compose ns/op |
| -------- | ----- | ------------ | ---------- | ------------- |
| Nim-ARC  | 2     | 4.929        | 3.091      | 12.128        |
| Nim-ARC  | 3     | 8.783        | 8.834      | 15.032        |
| Nim-ARC  | 4     | 11.590       | 12.026     | 17.725        |
| Nim-ORC  | 2     | 2.629        | 4.881      | 11.932        |
| Nim-ORC  | 3     | 8.498        | 8.438      | 14.880        |
| Nim-ORC  | 4     | 11.321       | 11.387     | 17.245        |
| Haskell  | 2     | 15.640       | 14.958     | 16.742        |
| Haskell  | 3     | 21.518       | 21.408     | 23.870        |
| Haskell  | 4     | 27.332       | 30.579     | 39.009        |
| Elixir   | 2     | 18.901       | 19.479     | 47.024        |
| Elixir   | 3     | 24.216       | 24.192     | 60.369        |
| Elixir   | 4     | 29.053       | 29.372     | 69.566        |
| F#       | 2     | 16.752       | 16.633     | 17.790        |
| F#       | 3     | 25.353       | 20.207     | 35.072        |
| F#       | 4     | 32.485       | 33.896     | 31.179        |
| OCaml    | 2     | 8.285        | 8.443      | 25.897        |
| OCaml    | 3     | 11.594       | 11.541     | 46.837        |
| OCaml    | 4     | 15.442       | 15.581     | 65.828        |

### Piper overhead relative to direct Nim

The most important measurement for `piper` is the cost of `:>` compared
with the equivalent direct call.

| Memory manager | Stage | `:>` overhead | `:>` efficiency |
| -------------- | ----- | ------------- | --------------- |
| Nim-ARC        | 2     | -37.30%       | 159.49%         |
| Nim-ARC        | 3     | +0.59%        | 99.42%          |
| Nim-ARC        | 4     | +3.76%        | 96.37%          |
| Nim-ORC        | 2     | +85.66%       | 53.86%          |
| Nim-ORC        | 3     | -0.72%        | 100.72%         |
| Nim-ORC        | 4     | +0.59%        | 99.42%          |

The 2-stage ARC/ORC results vary substantially between runs and should
not be treated as evidence that `:>` intrinsically makes a pipeline
faster or slower than direct calls. The 3-stage and 4-stage results are
more stable in this snapshot: `:>` remains within approximately four
percent of direct execution.

This is consistent with `:>` being a compile-time macro that lowers
the expression directly to ordinary function application rather than
introducing a runtime pipeline object.

### Composition

`>>>` is different from `:>`. `>>>` creates a reusable function value,
so it represents a different execution model from direct application.

In this benchmark, Nim's `>>>` measured:

| Memory manager | 2-stage      | 3-stage      | 4-stage      |
| -------------- | ------------ | ------------ | ------------ |
| ARC            | 12.128 ns/op | 15.032 ns/op | 17.725 ns/op |
| ORC            | 11.932 ns/op | 14.880 ns/op | 17.245 ns/op |

That is measurably more expensive than direct application, but the
absolute cost remains small for these pipelines.

The corresponding composition measurements in this benchmark were:

| Language | 2-stage | 3-stage | 4-stage |
| -------- | ------- | ------- | ------- |
| Nim-ARC  | 12.128  | 15.032  | 17.725  |
| Nim-ORC  | 11.932  | 14.880  | 17.245  |
| Haskell  | 16.742  | 23.870  | 39.009  |
| Elixir   | 47.024  | 60.369  | 69.566  |
| F#       | 17.790  | 35.072  | 31.179  |
| OCaml    | 25.897  | 46.837  | 65.828  |

These figures describe this particular implementation and workload.
They should not be interpreted as a general ranking of the languages.

### What the benchmark demonstrates

The benchmark is intended to answer a narrow question:

> Does adding `piper`'s syntax introduce significant runtime overhead?

For `:>`, the measured answer in the 3-stage and 4-stage cases is
effectively **no**: the operator remains close to the direct-call
baseline under both Nim ARC and ORC.

`>>>` has a measurable cost because it represents reusable,
first-class function composition rather than compile-time direct
application. That cost is still small in absolute terms for the
benchmark's tiny integer pipelines.

The result should therefore be read as:

```text
direct call
    ↓
:> pipe
    ≈ direct-call cost

>>> composition
    ↓
first-class composed function
    ≈ measurable but small additional cost
```

### Benchmark limitations

This is a microbenchmark, not a general application-performance
benchmark.

Microbenchmarks can be unreliable because they test a specific case
with a specific implementation, workload, toolchain, and environment.
Results can vary between machines and even between runs, so the numbers
should be taken with a grain of salt.

It measures very small integer transformations and is particularly
sensitive to compiler optimization, runtime implementation, CPU
frequency, cache state, JIT warmup, garbage-collection/runtime
behavior, and benchmark noise.

The benchmark should therefore be used to evaluate the implementation
strategy of `piper` rather than to make broad claims about overall
language performance.

Contributions that improve implementation fidelity, compiler/runtime
controls, or measurement methodology are welcome. Faster benchmark
implementations are also welcome when they preserve semantic
equivalence and remain methodologically fair. Any significant
benchmark-methodology changes should be documented alongside the
results.

---

## FAQ

**Q: Why `:>` and not `|>`?**

Because `|>` binds too tightly in Nim (level 8). It would prevent
mixing with `>>>` (level 5) without parentheses. `:>` is level 2, so
it mixes cleanly.

**Q: Can I have `|>` too?**

You could add it back, but it duplicates `:>` and creates confusion
about which to use. `:>` handles the intended value-to-function
application case.

**Q: What's the difference between `:>` and `>>>` in one sentence?**

`:>` applies a function to a value. `>>>` builds a function.
`:>` runs immediately when the expression is evaluated.
`>>>` builds a callable that runs when you invoke it.

**Q: Does `>>>` run anything when I write `f >>> g`?**

No. `f >>> g` is a function value. Nothing runs until you call the
result.

**Q: Can I use this with `async`?**

Not tested. `piper` works with synchronous functions. For async
pipelines, you'd need an async-aware operator or async-aware stages.

**Q: Does `:>` work with varargs or method call syntax?**

`:>` is designed for single-argument transformations. Functions used
as pipeline stages must be callable with the pipeline value as their
argument.

**Q: Is `Fn[A, B]` different from `proc(a: A): B {.closure.}`?**

No. `Fn[A, B]` is an alias for:

```nim
proc(a: A): B {.closure.}
```

A direct `>>>` pipeline may instead be generated as a `nimcall`
procedure when all of its stages are ordinary direct procedures. Use
`toFn` when an explicit `Fn[A, B]` value is required.

**Q: What does `toFn` do?**

`toFn` converts an ordinary `nimcall` procedure or a generated direct
pipeline into the first-class `Fn[A, B]` closure type.

```nim
let mathify: Fn[int, int] =
  toFn(
    double >>>
    addOne >>>
    square
  )
```

Calling `toFn` on an existing `Fn` does not introduce another wrapper.

**Q: Why does `>>>` have `{.gcsafe.}` warning disabled?**

Because `>>>` forwards calls to its stages, and whether those stages
are GC-safe cannot always be established at the definition site. Nim
can conservatively warn about this. The library suppresses the warning
inside its implementation module.

If you want strict GC-safety checking in your own code, configure the
warning policy explicitly rather than relying on the library's
internal suppression.

**Q: Can I store different pipelines in the same sequence?**

Yes, provided they have the same `Fn` signature:

```nim
let pipelines: seq[Fn[int, int]] =
  @[
    toFn(double >>> addOne),
    toFn(double >>> square),
  ]
```

For mixed signatures, use an appropriate sum type or another
type-erasure strategy.

**Q: Does `:>` short-circuit anything?**

No. `:>` is plain function application. Each stage runs
unconditionally.

For conditional pipelines, use `Option` or another explicit result
type and appropriate functions.

---

## Contributing

Bug reports, feature ideas, benchmark improvements, and pull requests
are welcome.

### Setup

```bash
git clone https://github.com/Dregacorp/piper.git
cd piper
nimble test
```

### Guidelines

* Add tests for any new behavior.
* Keep the public API surface small.
* Prefer clarity over cleverness.
* Update the README if you change the API.
* Keep benchmark comparisons semantically equivalent and document
  meaningful methodology changes.

### Reporting bugs

Include:

* Nim version (`nim --version`)
* The exact code that fails
* The full error message
* Expected vs actual behavior

---

## Versioning

`piper` follows [semantic versioning](https://semver.org/):

* **Major** — breaking API changes
* **Minor** — new features, backward compatible
* **Patch** — bug fixes, backward compatible

### Changelog

**0.1.0** — Initial release

* `:>` pipe operator
* `>>>` composition operator
* `Fn[A, B]` type alias
* `toFn` first-class function conversion
* Tests for both operators and their mixing
* Cross-platform CI
* Comparative benchmark suite

---

## License

BSD-3-Clause. See [LICENSE](LICENSE) for details.

---

## See also

* [Nim manual — operators](https://nim-lang.org/docs/manual.html#syntax-operators)
* [Nim manual — macros](https://nim-lang.org/docs/manual.html#macros)
* [Nim manual — templates](https://nim-lang.org/docs/manual.html#templates)
* [Elixir pipe operator](https://hexdocs.pm/elixir/Kernel.html#%7C%3E/2)
* [F# pipe and composition](https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/symbol-and-operator-reference/)
* [Haskell Control.Category](https://hackage.haskell.org/package/base/docs/Control-Category.html)
* [OCaml Fun module](https://ocaml.org/api/Fun.html)

---

<p align="center">
  <sub>Built with Nim. Pipe on.</sub>
</p>
