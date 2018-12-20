import pyobject

type 
  BltinFunction* = proc (args: seq[PyObject]): PyObject

  PyBltinFuncObject* = ref object of PyObject
    fun: BltinFunction

  Pbfo = PyBltinFuncObject


proc call*(f: Pbfo, args: seq[PyObject]): PyObject = 
  f.fun(args)


proc newPyBltinFuncObject*(fun: BltinFunction): Pbfo =
  result = new Pbfo
  result.fun = fun
