import strformat
import strutils
import algorithm

import ../Objects/bundle


proc fmtTraceBack(tb: TraceBack): string = 
  assert tb.fileName.ofPyStrObject
  let fileName = PyStrObject(tb.fileName).str
  assert tb.funName.ofPyStrObject
  let funName = PyStrObject(tb.funName).str
  fmt("  File \"{fileName}\", line {tb.lineNo}, in {funName}")


proc printTb*(excp: PyExceptionObject) = 
  var cur = excp
  var excpStrs: seq[string]
  while not cur.isNil:
    var singleExcpStrs: seq[string]
    singleExcpStrs.add "Traceback (most recent call last):"
    for tb in cur.traceBacks.reversed:
      singleExcpStrs.add tb.fmtTraceBack
    singleExcpStrs.add PyStrObject(tpMagic(BaseError, repr)(cur)).str
    excpStrs.add singleExcpStrs.join("\n")
    cur = cur.context
  let joinMsg = "\n\nDuring handling of the above exception, another exception occured\n\n"
  echo excpStrs.reversed.join(joinMsg)
