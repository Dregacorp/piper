## Function composition for piper.
##
## `>>>` composes two unary functions into a new function.
##
## `Fn[A, B]` is the public first-class unary function type.
##
## `flatCompose` composes two or more unary functions into a
## single closure without introducing nested composition closures.

import std/macros

{.push warning[GcUnsafe]: off.}

type
  Fn*[A, B] = proc(a: A): B {.closure.}
    ## A first-class closure from `A` to `B`.


proc `>>>`*[A, B, C](
    f: proc(a: A): B {.closure.},
    g: proc(b: B): C {.closure.}
  ): proc(a: A): C {.closure.} {.inline.} =
  ## Compose `f` and `g` left-to-right.
  ##
  ## Given:
  ##
  ##   f : A -> B
  ##   g : B -> C
  ##
  ## the resulting function is:
  ##
  ##   A -> C
  ##
  ## Nothing executes while the composition is constructed.

  result =
    proc(a: A): C =
      g(f(a))


proc extractUnaryProcTypes(
    typeNode: NimNode
  ): tuple[
    valid: bool,
    inputType: NimNode,
    outputType: NimNode
  ] =
  ## Extract the input and output types from a unary procedure.
  ##
  ## Nim 2.2.12 can expose a procedure type in compact form:
  ##
  ##   proc[ReturnType, InputType]
  ##
  ## For example:
  ##
  ##   proc(x: int): string
  ##
  ## may appear as:
  ##
  ##   proc[string, int]
  ##
  ## A normal nnkProcTy representation is also accepted.

  result.valid =
    false

  result.inputType =
    newEmptyNode()

  result.outputType =
    newEmptyNode()

  # --------------------------------------------------------------
  # Compact Nim procedure representation:
  #
  #   BracketExpr
  #     Sym "proc"
  #     ReturnType
  #     InputType
  # --------------------------------------------------------------

  if typeNode.kind == nnkBracketExpr:
    if typeNode.len != 3:
      return

    if typeNode[0].kind != nnkSym and
       typeNode[0].kind != nnkIdent:
      return

    if typeNode[0].repr != "proc":
      return

    result.outputType =
      typeNode[1]

    result.inputType =
      typeNode[2]

    result.valid =
      true

    return

  # --------------------------------------------------------------
  # Normal procedure type representation:
  #
  #   nnkProcTy(
  #     nnkFormalParams(
  #       ReturnType,
  #       identDefs(Parameter, ParameterType, Default)
  #     )
  #   )
  # --------------------------------------------------------------

  if typeNode.kind != nnkProcTy:
    return

  if typeNode.len < 1:
    return

  let formalParams =
    typeNode[0]

  if formalParams.kind != nnkFormalParams:
    return

  if formalParams.len != 2:
    return

  let parameter =
    formalParams[1]

  if parameter.kind != nnkIdentDefs:
    return

  if parameter.len != 3:
    return

  result.outputType =
    formalParams[0]

  result.inputType =
    parameter[1]

  result.valid =
    true


proc isStableStageSymbol(
    node: NimNode
  ): bool =
  ## Return true when `node` is an immutable/stable symbol whose
  ## function value cannot change after construction.
  ##
  ## These symbols can be referenced directly by the generated
  ## closure without creating an intermediate local capture.
  ##
  ## Mutable variables and parameters are deliberately excluded.
  ## They are captured into a generated `let` so that flatCompose
  ## observes their value at construction time.

  if node.kind != nnkSym:
    return false

  let kind =
    symKind(node)

  kind in {
    nskLet,
    nskConst,
    nskProc,
    nskFunc,
    nskConverter,
    nskMethod
  }


macro flatCompose*(
    args: varargs[typed]
  ): untyped =
  ## Compose two or more unary functions into one closure.
  ##
  ## Example:
  ##
  ##   let pipeline =
  ##     flatCompose(
  ##       double,
  ##       addOne,
  ##       square
  ##     )
  ##
  ## The generated closure is equivalent to:
  ##
  ##   proc(x) =
  ##     square(addOne(double(x)))
  ##
  ## Function-producing expressions are evaluated exactly once
  ## during construction.
  ##
  ## Stable immutable function symbols are used directly to avoid
  ## unnecessary capture locals.
  ##
  ## Mutable variables and arbitrary expressions are captured once.

  if args.len < 2:
    error(
      "flatCompose requires at least two functions",
      if args.len > 0:
        args[0]
      else:
        nil
    )

  var
    inputType: NimNode
    outputType: NimNode

    stageSymbols =
      newSeq[NimNode](args.len)

    statements =
      newStmtList()

  # --------------------------------------------------------------
  # Validate every stage and determine the complete signature.
  # --------------------------------------------------------------

  for index, arg in args:
    let typeNode =
      arg.getType

    let signature =
      extractUnaryProcTypes(
        typeNode
      )

    if not signature.valid:
      error(
        "flatCompose argument " &
        $index &
        " must be a unary procedure or closure; " &
        "got type: " &
        typeNode.repr,
        arg
      )

    if index == 0:
      inputType =
        signature.inputType

    if index == args.len - 1:
      outputType =
        signature.outputType

  # --------------------------------------------------------------
  # Prepare the stages.
  #
  # Stable immutable symbols:
  #
  #   use the original symbol directly.
  #
  # Mutable variables / arbitrary expressions:
  #
  #   let stageN = expression
  #
  # This gives us both correctness and the lowest practical
  # overhead for ordinary immutable function values.
  # --------------------------------------------------------------

  for index, arg in args:
    if isStableStageSymbol(arg):
      stageSymbols[index] =
        arg

    else:
      let stage =
        genSym(
          nskLet,
          "stage" & $index
        )

      stageSymbols[index] =
        stage

      statements.add(
        quote do:
          let `stage` =
            `arg`
      )

  # --------------------------------------------------------------
  # Build:
  #
  #   final(first(value))
  #
  # without creating intermediate composition closures.
  # --------------------------------------------------------------

  let input =
    genSym(
      nskParam,
      "value"
    )

  var body =
    newCall(
      stageSymbols[0],
      input
    )

  for index in 1 ..< stageSymbols.len:
    body =
      newCall(
        stageSymbols[index],
        body
      )

  # --------------------------------------------------------------
  # Generate exactly one closure.
  # --------------------------------------------------------------

  if outputType.kind == nnkEmpty:
    statements.add(
      quote do:
        (
          proc(`input`: `inputType`) {.closure.} =
            `body`
        )
    )
  else:
    statements.add(
      quote do:
        (
          proc(`input`: `inputType`): `outputType` {.closure.} =
            `body`
        )
    )

  # --------------------------------------------------------------
  # Return:
  #
  #   block:
  #     let stage0 = ...
  #     let stage1 = ...
  #     proc(value) = ...
  #
  # Only non-stable stages produce the local lets.
  # --------------------------------------------------------------

  result =
    newTree(
      nnkBlockExpr,
      newEmptyNode(),
      statements
    )


{.pop.}