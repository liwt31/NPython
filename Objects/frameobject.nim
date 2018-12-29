import strutils

import pyobject
import codeobject
import dictobject
import stringobject
import methodobject
import listobject
import ../Python/[opcode, bltinmodule]



type PyFrameObject* = ref object of PyObject 
  prev: PyFrameObject
  code*: PyCodeObject
  lastI*: int
  valStack: seq[PyObject]
  # dicts and sequences for variable lookup
  locals*: PyDictObject
  globals*: PyDictObject
  builtins*: PyDictObject
  # arguments of functions
  fastLocals*: seq[PyObject]

method `$`(f: PyFrameObject):string = 
  var stringSeq: seq[string]
  stringSeq.add("Frame")
  for obj in f.valStack:
    stringSeq.add($obj)
  stringSeq.add("Frame")
  stringSeq.join("\n\n")

#[
proc push*(f: PyFrameObject, obj: PyObject) = 
  f.valStack.add(obj)


proc top*(f: PyFrameObject): PyObject = 
  f.valStack[^1]


proc pop*(f: PyFrameObject): PyObject = 
  f.valStack.pop

proc setTop*(f: PyFrameObject, obj: PyObject) = 
  f.valStack[^1] = obj


]#
proc getConst*(f: PyFrameObject, idx: int): PyObject = 
  f.code.constants[idx]

proc getName*(f: PyFrameObject, idx: int): PyStringObject = 
  f.code.names[idx]


proc exhausted*(f: PyFrameObject): bool {. inline .} = 
  f.code.len <= f.lastI + 1


proc nextInstr*(f: PyFrameObject): (OpCode, int) {. inline .} = 
  inc f.lastI
  f.code.code[f.lastI]


proc jumpTo*(f: PyFrameObject, target: int) = 
  f.lastI = target - 1


proc setupBuiltin(f: PyFrameObject, name:string, obj: PyObject) = 
  let nameStrObj = newPyString(name)
  f.globals[nameStrObj] = obj

proc setupBuiltin(f: PyFrameObject, name: string, fun: BltinFunc) = 
  let nameStrObj = newPyString(name)
  f.globals[nameStrObj] = newPyNFunc(fun, nameStrObj)


proc newPyFrame*(code: PyCodeObject, args: seq[PyObject], prevF: PyFrameObject): PyFrameObject = 
  assert code != nil
  result = new PyFrameObject
  result.prev = prevF
  result.code = code
  result.lastI = -1
  result.locals = newPyDict()
  result.globals = newPyDict()
  if prevF != nil:
    result.globals.update(prevF.globals)
    result.globals.update(prevF.locals)
  result.builtins = newPyDict()
  # simple hack. Should build a "builtin" module in the future
  result.setupBuiltin("print", builtinPrint)
  result.setupBuiltin("dir", builtinDir)
  result.setupBuiltin("list", pyListObjectType)
  result.fastLocals = newSeq[PyObject](code.localVars.len)
  for idx, arg in args:
    result.fastLocals[idx] = arg

