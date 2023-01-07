
echo ""
echo ""


import std/enumerate
import std/macros


var ctx : seq[int]



const def_64_cpp = defined(def_64_cpp)
const def_32_cpp = defined(def_32_cpp)

# include prelude
# https://github.com/achesak/nim-pythonfile




# decimal: https://juancarlospaco.github.io/cpython/decimal

when defined(emscripten) or defined(wasi):
    echo "dynlib not available at all on WebAssembly"
else:
    when not defined(def_NODYNLIB_cpp):
        echo "dynlib turned off explicitely"
        # stdlib: https://github.com/juancarlospaco/cpython
        # nimble install cpython
        # nimble install https://github.com/juancarlospaco/cpython.git

        import dynlib
        import cpython/decimal


# nimpy: https://github.com/yglukhov/nimpy
# import nimpy

# pylib: https://github.com/Yardanico/nimpylib
import pylib



# call python from Nim
# https://github.com/marcoapintoo/nim-pythonize
# Pythonize is a high-level wrapper to interface the Nim and Python programming languages.


proc genProc(define, body: NimNode): NimNode =
  # Copy the defines (arguments, return type, proc name)
  var define = define
  var
    startIdx = 1 # start index of arguments of the proc
    stopIdx = define.len - 1 # end index

  # First argument is the return type of the procedure
  var args = @[newIdentNode("auto")]
  # If it's a infix ->, it's a type hint for the return type
  if define.kind == nnkInfix:
    if define[0].strVal != "->":
      error("expected a type hint arrow", define)
    # Replace the return type
    args[0] = define[^1]
    define = define[1] # Discard the arrow

  var procName = define[0]

  # Loop over all arguments except the procedure name
  for i in startIdx..stopIdx:
    # Argument name
    let arg = define[i]
    # arg = 5
    if arg.kind == nnkExprEqExpr:
      args.add newIdentDefs(arg[0], newEmptyNode(), arg[1])
    # arg: int or arg: int ~ 5
    elif arg.kind == nnkExprColonExpr:
      # With default value with ~
      if arg[1].kind == nnkInfix and arg[1][0].strVal == "~":
        args.add newIdentDefs(arg[0], arg[1][1], arg[1][2])
      # No default value, just a type hint
      else:
        args.add newIdentDefs(arg[0], arg[1], newEmptyNode())
    else:
      # Just add argument: auto and hope for the best
      args.add newIdentDefs(arg, ident("auto"), newEmptyNode())
  # Convert a python "doc" comment into a nim doc comment
  if body[0].kind == nnkTripleStrLit:
    body[0] = newCommentStmtNode($body[0])
  # Finally create a procedure and add it to result!
  return newProc(procName, args, body, nnkProcDef)

macro def*(args, body: untyped): untyped =
  result = genProc(args, body)

echo ""
echo f"64 Bits : {def_64_cpp}  32 Bits: {def_32_cpp} WASI:{defined(wasi)}"
echo ""

when defined(reactor):
    proc nimMain {.importC: "NimMain", nodecl.}

when defined(wasi):

    proc flockfile(file:cint):cint {.exportC} =
        0

    proc funlockfile(file:cint):cint {.exportC} =
        0

    proc setjmp(jmp_buf:cint):cint {.exportC} =
        0


macro c_label*(labelName, body: untyped): untyped =
  expectKind(labelName, nnkIdent)
  let name = repr(labelName)
  result = quote do:
    {.emit: `name` & ":".}
    block:
      `body`

macro c_goto*(labelName: untyped): untyped =
  expectKind(labelName, nnkIdent)
  let name = repr(labelName)
  result = quote do:
    {.emit: "goto " & `name` & ";".}

template c_jmp*(labelName: untyped): untyped =
  c_goto labelName













