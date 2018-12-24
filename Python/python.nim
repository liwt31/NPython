import strformat
import os

import cligen

import neval
import compile
import ../Parser/[lexer, parser]
import ../Objects/[pyobject, frameobject, codeobject, exceptions]
import ../Utils/utils


proc interactiveShell =
  var finished = true
  var rootCst: ParseNode
  var lexer: Lexer
  var prevF: PyFrameObject
  echo "NPython 0.0.1"
  while true:
    var input: TaintedString
    if finished:
      stdout.write(">>> ")
    else:
      stdout.write("... ")

    try:
      input = stdin.readline()
    except EOFError:
      quit(0)

    try:
      (rootCst, lexer) = parseWithState(input, Mode.Single, rootCst, lexer)
    except SyntaxError:
      echo getCurrentExceptionMsg()
      rootCst = nil
      lexer = nil
      continue

    #echo rootCst
    finished = rootCst.finished
    #echo fmt"Finished: {finished}"
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
  if filenames.len == 0:
    interactiveShell()

  let filename = filenames[0]

  if not filename.existsFile:
    echo "File does not exist"
  let input = readFile(filename)
  var retObj = input.runString
  echo retObj


when isMainModule:
  dispatch(nPython)
