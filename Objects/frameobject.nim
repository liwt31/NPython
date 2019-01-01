import strutils

import pyobject
import codeobject
import funcobject
import dictobject
import stringobject
import methodobject
import listobject
import rangeobject
import ../Python/[opcode, bltinmodule]



type PyFrameObject* = ref object of PyObject 
  back: PyFrameObject
  code*: PyCodeObject
  lastI*: int
  valStack: seq[PyObject]
  # dicts and sequences for variable lookup
  # locals and builtins not used for now
  locals*: PyDictObject
  globals*: PyDictObject
  builtins*: PyDictObject
  fastLocals*: seq[PyObject]

method `$`(f: PyFrameObject):string = 
  var stringSeq: seq[string]
  stringSeq.add("Frame")
  for obj in f.valStack:
    stringSeq.add($obj)
  stringSeq.add("Frame")
  stringSeq.join("\n\n")

proc getConst*(f: PyFrameObject, idx: int): PyObject = 
  f.code.constants[idx]

proc getName*(f: PyFrameObject, idx: int): PyStrObject = 
  f.code.names[idx]

proc setupBuiltin(f: PyFrameObject, name:string, obj: PyObject) = 
  let nameStrObj = newPyString(name)
  f.globals[nameStrObj] = obj

proc setupBuiltin(f: PyFrameObject, name: string, fun: BltinFunc) = 
  let nameStrObj = newPyString(name)
  f.globals[nameStrObj] = newPyNFunc(fun, nameStrObj)

proc newPyFrame*(fun: PyFunctionObject, 
                 args: seq[PyObject], 
                 back: PyFrameObject): PyFrameObject = 
  let code = fun.code
  assert code != nil
  result = new PyFrameObject
  result.back = back
  result.code = code
  result.lastI = -1
  # locals not used for now
  result.locals = nil
  result.globals = fun.globals
  # builtins not used for now
  result.builtins = nil
  # simple hack. Should build a "builtin" module in the future
  result.setupBuiltin("print", builtinPrint)
  result.setupBuiltin("dir", bltinDir)
  result.setupBuiltin("list", pyListObjectType)
  result.setupBuiltin("range", pyRangeObjectType)
  result.setupBuiltin("type", bltinType)
  result.fastLocals = newSeq[PyObject](code.localVars.len)
  for idx, arg in args:
    result.fastLocals[idx] = arg

