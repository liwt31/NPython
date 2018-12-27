import strformat
import macros except name

import pyobject
import stringobject


type
  PyNFuncObject* = ref object of PyObject

  PyBltinFuncObject* = ref object of PyNFuncObject
    fun: BltinFunc
    name: PyStringObject

  PyBltinMethodObject* = ref object of PyNFuncObject
    fun: BltinMethod
    name: PyStringObject
    self: PyObject

  PyUnaryFuncObject* = ref object of PyNFuncObject
    fun: UnaryFunc
    name: PyStringObject
    self: PyObject

  PyBinaryFuncObject* = ref object of PyNFuncObject
    fun: BinaryFunc
    name: PyStringObject
    self: PyObject

let pyNFuncObjectType = newPyType("Nim-function")


method call*(f: PyObject, args: seq[PyObject]): PyObject {. base .} = 
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


proc newPyNFunc*(fun: BltinFunc, name: PyStringObject): PyBltinFuncObject =
  impl(false)


proc newPyNFunc*(fun: UnaryFunc, name: PyStringObject, self: PyObject): PyUnaryFuncObject = 
  impl


proc newPyNFunc*(fun: BinaryFunc, name: PyStringObject, self: PyObject): PyBinaryFuncObject = 
  impl


proc newPyNFunc*(fun: BltinMethod, name: PyStringObject, self: PyObject): PyBltinMethodObject = 
  impl


