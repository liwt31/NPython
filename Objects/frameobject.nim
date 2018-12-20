import strutils

import pyobject
import codeobject
import dictobject
import stringobject
import Python/opcode



type PyFrameObject* = ref object of PyObject
  code: PyCodeObject
  lastI: int
  valStack: seq[PyObject]
  locals*: PyDictObject
  globals*: PyDictObject

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

proc newPyFrame*(code: PyCodeObject): PyFrameObject = 
  result = new PyFrameObject
  result.code = code
  result.lastI = -1
  result.locals = newPyDict()
  result.globals = newPyDict()



