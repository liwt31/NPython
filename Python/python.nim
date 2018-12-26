import strformat
import rdstdin
import os

import cligen

import neval
import compile
import lifecycle
import ../Parser/[lexer, parser]
import ../Objects/[pyobject, frameobject, codeobject]
import ../Utils/utils


proc interactiveShell =
  var finished = true
  var rootCst: ParseNode
  var lexer: Lexer
  var prevF: PyFrameObject
  echo "NPython 0.0.1"
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
    
    let f = newPyFrame(co, @[], prevF)
    var retObj = f.evalFrame
    if retObj.isThrownException:
      echo retObj
    else:
      prevF = f
    rootCst = nil



proc nPython(filenames: seq[string], dis = false) =
  pyInit()
  if filenames.len == 0:
    interactiveShell()

  let filename = filenames[0]

  if not filename.existsFile:
    echo "File does not exist"
  let input = readFile(filename)
  var retObj = input.runString
  if retObj.isThrownException:
    echo retObj


when isMainModule:
  dispatch(nPython)
