import pyobject
import exceptions

type
  PyFuncWrapperObject* = ref object of PyObject

  PyBltinFuncObject* = ref object of PyFuncWrapperObject
    fun*: BltinFunc

  PyUnaryFuncObject* = ref object of PyFuncWrapperObject
    fun*: UnaryFunc

  PyBinaryFuncObject* = ref object of PyFuncWrapperObject
    fun*: BinaryFunc


# make function defination a macro
proc call*(f: PyBltinFuncObject, args: seq[PyObject]): PyObject = 
  f.fun(args)


proc newPyWrapperObject*(fun: BltinFunc): PyBltinFuncObject =
  new result
  result.fun = fun


proc newPyWrapperObject*(fun: UnaryFunc): PyUnaryFuncObject = 
  new result
  result.fun = fun


proc newPyWrapperObject*(fun: BinaryFunc): PyBinaryFuncObject = 
  new result
  result.fun = fun
