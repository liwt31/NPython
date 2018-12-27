import strformat
import macros

import pyobject
import stringobject


type
  PyNFuncObject* = ref object of PyObject

  PyBltinFuncObject* = ref object of PyNFuncObject
    fun: BltinFunc

  PyBltinMethodObject* = ref object of PyNFuncObject
    self: PyObject
    fun: BltinMethod

  PyUnaryFuncObject* = ref object of PyNFuncObject
    self: PyObject
    fun: UnaryFunc

  PyBinaryFuncObject* = ref object of PyNFuncObject
    self: PyObject
    fun: BinaryFunc

let pyNFuncObjectType = newPyType("Nim-function")


method call*(f: PyObject, args: seq[PyObject]): PyObject {. base .} = 
  newTypeError(fmt"{f.pyType.name} is not callable")


method call*(f: PyBltinFuncObject, args: seq[PyObject]): PyObject = 
  f.fun(args)

method call*(f: PyUnaryFuncObject, args: seq[PyObject]): PyObject = 
  if args.len != 0:
    return newTypeError(fmt"expected 0 arguments, got {args.len}")
  f.fun(f.self)


method call*(f: PyBinaryFuncObject, args: seq[PyObject]): PyObject = 
  if args.len != 1:
    return newTypeError(fmt"expected 1 arguments, got {args.len}")
  f.fun(f.self, args[0])


method call*(f: PyBltinMethodObject, args: seq[PyObject]): PyObject = 
  f.fun(f.self, args)


template impl(withSelf=true) = 
  new result
  result.fun = fun
  result.pyType = pyNFuncObjectType
  when withSelf:
    result.self = self


proc newPyNFunc*(fun: BltinFunc): PyBltinFuncObject =
  impl(false)


proc newPyNFunc*(fun: UnaryFunc, self: PyObject): PyUnaryFuncObject = 
  impl


proc newPyNFunc*(fun: BinaryFunc, self: PyObject): PyBinaryFuncObject = 
  impl


proc newPyNFunc*(fun: BltinMethod, self: PyObject): PyBltinMethodObject = 
  impl


