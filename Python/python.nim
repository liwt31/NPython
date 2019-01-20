import strformat
import rdstdin
import os

import cligen

import neval
import compile
import coreconfig
import traceback
import lifecycle
import ../Parser/[lexer, parser]
import ../Objects/bundle
import ../Utils/utils



proc interactiveShell =
  var finished = true
  # the root of the concrete syntax tree. Keep this when user input multiple lines
  var rootCst: ParseNode
  let lexer = newLexer("<stdin>")
  var prevF: PyFrameObject
  echo "NPython 0.1.0"
  while true:
    var input: string
    var prompt: string
    if finished:
      prompt = ">>> "
      rootCst = nil
      lexer.clearIndent
    else:
      prompt = "... "
      assert (not rootCst.isNil)

    try:
      input = readLineFromStdin(prompt)
    except EOFError, IOError:
      quit(0)

    try:
      rootCst = parseWithState(input, lexer, Mode.Single, rootCst)
    except SyntaxError:
      let e = SyntaxError(getCurrentException())
      let excpObj = fromBltinSyntaxError(e, newPyStr("<stdin>"))
      excpObj.printTb
      finished = true
      continue

    finished = rootCst.finished
    if not finished:
      continue

    let compileRes = compile(rootCst, "<stdin>")
    if compileRes.isThrownException:
      PyExceptionObject(compileRes).printTb
      continue
    let co = PyCodeObject(compileRes)

    when defined(debug):
      echo co

    var globals: PyDictObject
    if prevF != nil:
      globals = prevF.globals
    else:
      globals = newPyDict()
    let fun = newPyFunc(newPyString("Bla"), co, globals)
    let f = newPyFrame(fun)
    var retObj = f.evalFrame
    if retObj.isThrownException:
      PyExceptionObject(retObj).printTb
    else:
      prevF = f

proc nPython(args: seq[string]) =
  pyInit(args)
  if pyConfig.filepath == "":
    interactiveShell()

  if not pyConfig.filepath.existsFile:
    echo fmt"File does not exist ({pyConfig.filepath})"
    quit()
  let input = readFile(pyConfig.filepath)
  var retObj = runString(input, pyConfig.filepath)
  if retObj.isThrownException:
    PyExceptionObject(retObj).printTb


when isMainModule:
  dispatch(nPython)
