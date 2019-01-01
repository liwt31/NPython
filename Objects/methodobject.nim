import strformat

import pyobject except name
import stringobject


type
  PyNFuncObject* = ref object of PyObject

  PyBltinFuncObject* = ref object of PyNFuncObject
    fun: BltinFunc
    name: PyStrObject

  PyBltinMethodObject* = ref object of PyNFuncObject
    fun: BltinMethod
    name: PyStrObject
    self: PyObject

  PyUnaryFuncObject* = ref object of PyNFuncObject
    fun: UnaryFunc
    name: PyStrObject
    self: PyObject

  PyBinaryFuncObject* = ref object of PyNFuncObject
    fun: BinaryFunc
    name: PyStrObject
    self: PyObject

let pyNFuncObjectType = newPyType("Nim-function")


method call*(f: PyObject, args: seq[PyObject]): PyObject {. base .} = 
  let callFunc = f.pyType.magicMethods.call
  if callFunc != nil:
    return callFunc(f, args)
  newTypeError(fmt"{f.pyType.name} is not callable")


method call*(f: PyBltinFuncObject, args: seq[PyObject]): PyObject = 
  f.fun(args)

method call*(f: PyUnaryFuncObject, args: seq[PyObject]): PyObject = 
  checkArgNum(0)
  f.fun(f.self)


method call*(f: PyBinaryFuncObject, args: seq[PyObject]): PyObject = 
  checkArgNum(1)
  f.fun(f.self, args[0])


method call*(f: PyBltinMethodObject, args: seq[PyObject]): PyObject = 
  f.fun(f.self, args)


template impl(withSelf=true) = 
  new result
  result.fun = fun
  result.name = name
  when withSelf:
    result.self = self
  result.pyType = pyNFuncObjectType


proc newPyNFunc*(fun: BltinFunc, name: PyStrObject): PyBltinFuncObject =
  impl(false)


proc newPyNFunc*(fun: UnaryFunc, name: PyStrObject, self: PyObject): PyUnaryFuncObject = 
  impl


proc newPyNFunc*(fun: BinaryFunc, name: PyStrObject, self: PyObject): PyBinaryFuncObject = 
  impl


proc newPyNFunc*(fun: BltinMethod, name: PyStrObject, self: PyObject): PyBltinMethodObject = 
  impl


