import pyobject
import exceptions

type 
  BltinFuncSignature* = proc (args: seq[PyObject]): (PyObject, PyExceptionObject)

  PyBltinFuncObject* = ref object of PyObject
    fun: BltinFuncSignature

  Pbfo = PyBltinFuncObject


# make function defination a macro
proc call*(f: Pbfo, args: seq[PyObject]): (PyObject, PyExceptionObject) = 
  f.fun(args)


proc newPyBltinFunc*(fun: BltinFuncSignature): Pbfo =
  result = new Pbfo
  result.fun = fun
