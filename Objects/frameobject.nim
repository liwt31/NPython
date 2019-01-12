import strutils

import pyobject
import baseBundle
import codeobject
import funcobject
import dictobject
import cellobject
import ../Python/opcode

declarePyType Frame():
  back: PyFrameObject
  code: PyCodeObject
  # dicts and sequences for variable lookup
  # locals not used for now
  # locals*: PyDictObject
  globals: PyDictObject
  # builtins: PyDictObject
  fastLocals: seq[PyObject]
  cellVars: seq[PyCellObject]

proc newPyFrame*: PyFrameObject = 
  newPyFrameSimple()

