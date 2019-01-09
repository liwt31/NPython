import strformat
import rdstdin
import os

import cligen

import neval
import compile
import coreconfig
import lifecycle
import ../Parser/[lexer, parser]
import ../Objects/bundle
import ../Utils/utils


proc interactiveShell =
  var finished = true
  var rootCst: ParseNode
  var lexer: Lexer
  var prevF: PyFrameObject
  echo "NPython 0.1.0"
  while true:
    var input: TaintedString
    var prompt: string
    if finished:
      prompt = ">>> "
    else:
      prompt = "... "

    try:
      input = readLineFromStdin(prompt)
    except EOFError, IOError:
      quit(0)

    try:
      (rootCst, lexer) = parseWithState(input, Mode.Single, rootCst, lexer)
    except SyntaxError:
      echo getCurrentExceptionMsg()
      rootCst = nil
      lexer = nil
      continue

    finished = rootCst.finished
    if not finished:
      continue

    var co: PyCodeObject
    try:
      co = compile(rootCst)
    except SyntaxError:
      echo getCurrentExceptionMsg()
      rootCst = nil
      lexer = nil
      continue

    when defined(debug):
      echo co

    var globals: PyDictObject
    if prevF != nil:
      globals = prevF.globals
    else:
      globals = newPyDict()
    let fun = newPyFunc(newPyString("Bla"), co, globals)
    let f = newPyFrame(fun, @[], prevF)
    var retObj = f.evalFrame
    if retObj.isThrownException:
      echo PyExceptionObject(retObj).excpStrWithContext
    else:
      prevF = f
    rootCst = nil



proc nPython(args: seq[string]) =
  pyInit(args)
  if pyConfig.filepath == "":
    interactiveShell()

  if not pyConfig.filepath.existsFile:
    echo fmt"File does not exist ({pyConfig.filepath})"
    quit()
  let input = readFile(pyConfig.filepath)
  var retObj = input.runString
  if retObj.isThrownException:
    echo PyExceptionObject(retObj).excpStrWithContext


when isMainModule:
  dispatch(nPython)
