import pyobject
import exceptions

# make function defination a macro
proc call*(f: PyBltinFuncObject, args: seq[PyObject]): PyObject = 
  f.fun(args)


proc newPyBltinFunc*(fun: BltinFunc): PyBltinFuncObject =
  new result
  result.fun = fun
