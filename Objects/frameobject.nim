import strutils

import pyobject
import codeobject
import funcobject
import dictobject
import stringobject
import ../Python/opcode

type
  TryBlock = object
    tp: OpCode # Borrowed from CPython. Currently not used in NPython.
    handler: int
    sPtr: int
    

declarePyType Frame():
  back: PyFrameObject
  code: PyCodeObject
  # dicts and sequences for variable lookup
  # locals not used for now
  # locals*: PyDictObject
  globals: PyDictObject
  # builtins: PyDictObject
  fastLocals: seq[PyObject]

  # in CPython this is a finite (20, CO_MAXBLOCKS) sized array
  # safety is ensured by the compiler
  blockStack: seq[TryBlock]


proc newPyFrame*: PyFrameObject = 
  newPyFrameSimple()

proc hasTryBlock*(self: PyFrameObject): bool {. cdecl inline .} = 
  0 < self.blockStack.len

proc getTryHandler*(self: PyFrameObject): int {. cdecl inline .} = 
  self.blockStack[^1].handler
  

proc addTryBlock*(self: PyFrameObject, tp: OpCode, handler, sPtr: int) {. cdecl inline .} = 
  self.blockStack.add(TryBlock(tp:tp, handler:handler, sPtr:sPtr))

proc popTryBlock*(self: PyFrameObject): int {. cdecl inline .} = 
  result = self.blockStack[^1].sPtr
  discard self.blockStack.pop
