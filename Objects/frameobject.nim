import strutils

import pyobject
import codeobject
import dictobject
import stringobject
import methodobject
import ../Python/[opcode, bltinmodule]



type PyFrameObject* = ref object of PyObject 
  prev: PyFrameObject
  code: PyCodeObject
  lastI: int
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

proc push*(f: PyFrameObject, obj: PyObject) = 
  f.valStack.add(obj)

proc pop*(f: PyFrameObject): PyObject = 
  f.valStack.pop


proc getConst*(f: PyFrameObject, idx: int): PyObject = 
  f.code.constants[idx]

proc getName*(f: PyFrameObject, idx: int): PyStringObject = 
  f.code.names[idx]


proc exhausted*(f: PyFrameObject): bool = 
  f.code.len <= f.lastI + 1


proc nextInstr*(f: PyFrameObject): (OpCode, int) = 
  inc f.lastI
  var (opCode, opArg) = f.code.code[f.lastI]
  result = (OpCode(opCode), opArg)


proc jumpTo*(f: PyFrameObject, target: int) = 
  f.lastI = target - 1


proc setupBuiltin(f: PyFrameObject, name: string, fun: BltinFuncSignature) = 
  f.globals[newPyString(name)] = newPyBltinFunc(fun)


proc newPyFrame*(code: PyCodeObject, fastLocals: seq[PyObject], prevF: PyFrameObject): PyFrameObject = 
  result = new PyFrameObject
  result.prev = prevF
  result.code = code
  result.lastI = -1
  result.locals = newPyDict()
  if prevF != nil:
    result.globals = prevF.globals.combine(prevF.locals)
  else:
    result.globals = newPyDict()
  result.builtins = newPyDict()
  result.setupBuiltin("print", builtinPrint)
  result.fastLocals = fastLocals

