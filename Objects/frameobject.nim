import strutils

import pyobject
import baseBundle
import codeobject
import dictobject
import cellobject
import ../Python/opcode

declarePyType Frame():
  # currently not used?
  back: PyFrameObject
  code: PyCodeObject
  # dicts and sequences for variable lookup
  # locals not used for now
  # locals*: PyDictObject
  globals: PyDictObject
  # builtins: PyDictObject
  fastLocals: seq[PyObject]
  cellVars: seq[PyCellObject]


# initialized in neval.nim
proc newPyFrame*: PyFrameObject = 
  newPyFrameSimple()

proc toPyDict*(f: PyFrameObject): PyDictObject {. cdecl .} = 
  result = newPyDict()
  let c = f.code
  for idx, v in f.fastLocals:
    if v.isNil:
      continue
    result[c.localVars[idx]] = v
  let n = c.cellVars.len
  for idx, cell in f.cellVars[0..<n]:
    assert (not cell.isNil)
    if cell.refObj.isNil:
      continue
    result[c.cellVars[idx]] = cell.refObj
  for idx, cell in f.cellVars[n..^1]:
    assert (not cell.isNil)
    if cell.refObj.isNil:
      continue
    result[c.freeVars[idx]] = cell.refObj

