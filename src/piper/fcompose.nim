## Function composition for piper.
##
## Public API:
##
##   Fn[A, B] — first-class unary closure type
##   >>>       — left-to-right function composition
##   :>        — immediate value-to-function application
##   toFn      — explicit conversion to Fn
##
## The implementation is compile-time oriented.
##
## Example:
##
##   let pipeline =
##     double >>>
##     addOne >>>
##     square
##
## generates one ordinary nimcall procedure equivalent to:
##
##   proc(x: int): int =
##     square(addOne(double(x)))
##
## Immediate application:
##
##   5 :> double >>> addOne >>> square
##
## is lowered directly to:
##
##   square(addOne(double(5)))
##
## No public flatCompose helper is required.

import std/macros
import std/typetraits

{.push warning[GcUnsafe]: off.}


type
  Fn*[A, B] = proc(a: A): B {.closure.}
    ## First-class unary closure from `A` to `B`.


# ============================================================================
# AST helpers
# ============================================================================

proc unwrapPar(
    node: NimNode
  ): NimNode =
  ## Remove redundant parenthesis nodes.

  result =
    node

  while result.kind == nnkPar:
    result =
      result[0]


proc isComposeNode(
    node: NimNode
  ): bool =
  ## Return true when `node` is a syntactic `>>>` expression.

  let current =
    unwrapPar(node)

  if current.kind != nnkInfix:
    return false

  if current.len != 3:
    return false

  let operator =
    current[0]

  if operator.kind notin {nnkIdent, nnkSym}:
    return false

  operator.repr == ">>>"


proc collectComposeStages(
    node: NimNode,
    stages: var seq[NimNode]
  ) =
  ## Flatten a syntactic composition tree.
  ##
  ##   a >>> b >>> c >>> d
  ##
  ## becomes:
  ##
  ##   [a, b, c, d]

  let current =
    unwrapPar(node)

  if isComposeNode(current):
    collectComposeStages(
      current[1],
      stages
    )

    collectComposeStages(
      current[2],
      stages
    )

    return

  stages.add(
    current
  )


# ============================================================================
# Procedure type extraction
# ============================================================================

proc extractUnaryProcTypes(
    typeNode: NimNode
  ): tuple[
    valid: bool,
    inputType: NimNode,
    outputType: NimNode
  ] =
  ## Extract input/output types from a unary procedure type.

  result.valid =
    false

  result.inputType =
    newEmptyNode()

  result.outputType =
    newEmptyNode()

  # --------------------------------------------------------------------------
  # Compact representation.
  # --------------------------------------------------------------------------

  if typeNode.kind == nnkBracketExpr:
    if typeNode.len == 3:
      let head =
        typeNode[0]

      if head.kind in {nnkSym, nnkIdent} and
         head.repr == "proc":

        result.outputType =
          typeNode[1]

        result.inputType =
          typeNode[2]

        result.valid =
          true

        return

  # --------------------------------------------------------------------------
  # Normal procedure type representation.
  # --------------------------------------------------------------------------

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

  if parameter.len < 3:
    return

  result.outputType =
    formalParams[0]

  result.inputType =
    parameter[1]

  result.valid =
    true


# ============================================================================
# Stage classification
# ============================================================================

proc isStableStageSymbol(
    node: NimNode
  ): bool =
  ## Return true for callable symbols whose value can be referenced directly.
  ##
  ## Other expressions are evaluated once into a generated `let`.

  if node.kind != nnkSym:
    return false

  case symKind(node)
  of nskLet,
     nskConst,
     nskProc,
     nskFunc,
     nskConverter,
     nskMethod:
    true

  else:
    false


proc isDirectOrdinaryProc(
    node: NimNode
  ): bool =
  ## Return true for a directly referenced procedure that does not
  ## require a closure environment.

  if node.kind != nnkSym:
    return false

  case symKind(node)
  of nskProc,
     nskFunc,
     nskConverter,
     nskMethod:
    discard

  else:
    return false

  not hasClosure(node)


# ============================================================================
# Internal flattened composition
# ============================================================================

macro makeComposed(
    args: varargs[typed]
  ): untyped =
  ## Generate one callable from a flattened sequence of stages.
  ##
  ## Ordinary direct procedures become one normal nimcall procedure.
  ##
  ## Dynamic/closure stages become one closure.

  if args.len < 2:
    error(
      ">>> requires at least two unary functions",
      if args.len > 0:
        args[0]
      else:
        nil
    )

  var
    inputType =
      newEmptyNode()

    outputType =
      newEmptyNode()

    stageSymbols =
      newSeq[NimNode](args.len)

    statements =
      newStmtList()

    allDirectOrdinary =
      true

  # --------------------------------------------------------------------------
  # Validate stages and establish the complete signature.
  # --------------------------------------------------------------------------

  for index, arg in args:
    let typeNode =
      arg.getType

    let signature =
      extractUnaryProcTypes(
        typeNode
      )

    if not signature.valid:
      error(
        ">>> stage " &
        $index &
        " must be a unary procedure; got type: " &
        typeNode.repr,
        arg
      )

    if index == 0:
      inputType =
        signature.inputType

    if index == args.len - 1:
      outputType =
        signature.outputType

    if not isDirectOrdinaryProc(arg):
      allDirectOrdinary =
        false

  # --------------------------------------------------------------------------
  # Prepare stages.
  #
  # Stable symbols are referenced directly.
  #
  # Dynamic values and expressions are evaluated once.
  # --------------------------------------------------------------------------

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

  # --------------------------------------------------------------------------
  # Build:
  #
  #   stageN(stageN-1(...stage0(value)...))
  # --------------------------------------------------------------------------

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

  # --------------------------------------------------------------------------
  # Generate the callable.
  #
  # IMPORTANT:
  #
  # Do NOT mark the ordinary path `{.inline.}`.
  #
  # `inline` is a calling convention in Nim. We specifically want
  # an ordinary nimcall procedure here so that:
  #
  #   toFn(pipeline)
  #
  # can perform Nim's normal nimcall -> closure conversion.
  # --------------------------------------------------------------------------

  let generatedProc =
    if outputType.kind == nnkEmpty:

      if allDirectOrdinary:
        quote do:
          (
            proc(`input`: `inputType`) {.nimcall.} =
              `body`
          )

      else:
        quote do:
          (
            proc(`input`: `inputType`) {.closure.} =
              `body`
          )

    else:

      if allDirectOrdinary:
        quote do:
          (
            proc(`input`: `inputType`): `outputType` {.nimcall.} =
              `body`
          )

      else:
        quote do:
          (
            proc(`input`: `inputType`): `outputType` {.closure.} =
              `body`
          )

  if statements.len == 0:
    result =
      generatedProc

  else:
    statements.add(
      generatedProc
    )

    result =
      newTree(
        nnkBlockExpr,
        newEmptyNode(),
        statements
      )


# ============================================================================
# Public >>>
# ============================================================================

macro `>>>`*(
    lhs: untyped,
    rhs: untyped
  ): untyped =
  ## Compose functions from left to right.
  ##
  ##   a >>> b >>> c
  ##
  ## is flattened before the typed implementation is generated.

  var stages:
    seq[NimNode] = @[]

  collectComposeStages(
    lhs,
    stages
  )

  collectComposeStages(
    rhs,
    stages
  )

  if stages.len < 2:
    error(
      ">>> requires at least two unary functions",
      lhs
    )

  result =
    newCall(
      bindSym("makeComposed")
    )

  for stage in stages:
    result.add(
      stage
    )


# ============================================================================
# Public :>
# ============================================================================

macro `:>`*(
    value: typed,
    stage: untyped
  ): untyped =
  ## Apply a value immediately through one function or an entire
  ## composition segment.
  ##
  ##   x :> a >>> b >>> c
  ##
  ## becomes:
  ##
  ##   c(b(a(x)))
  ##
  ## without constructing a composition object.

  var stages:
    seq[NimNode] = @[]

  let normalizedStage =
    unwrapPar(stage)

  if isComposeNode(normalizedStage):
    collectComposeStages(
      normalizedStage,
      stages
    )

  else:
    stages.add(
      normalizedStage
    )

  if stages.len == 0:
    error(
      ":> requires a callable stage",
      stage
    )

  var expression =
    newCall(
      stages[0],
      value
    )

  for index in 1 ..< stages.len:
    expression =
      newCall(
        stages[index],
        expression
      )

  result =
    expression


# ============================================================================
# Public toFn
# ============================================================================

proc toFn*[A, B](
    value: proc(a: A): B {.nimcall.}
  ): Fn[A, B] {.inline.} =
  ## Convert an ordinary nimcall procedure into one closure.
  ##
  ## This is the explicit boundary between the zero-environment
  ## `>>>` representation and the first-class `Fn` representation.

  result =
    proc(a: A): B =
      value(a)


proc toFn*[A, B](
    value: Fn[A, B]
  ): Fn[A, B] {.inline.} =
  ## An existing Fn value is already a closure.
  ##
  ## No additional wrapping is introduced.

  value


{.pop.}