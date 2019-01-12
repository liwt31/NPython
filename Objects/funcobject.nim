import pyobject
import codeobject
import stringobject
import dictobject
import tupleobject

declarePyType Func(tpToken):
  name: PyStrObject
  code: PyCodeObject
  globals: PyDictObject
  closure: PyTupleObject # could be nil


proc newPyFunc*(name: PyStrObject, 
                code: PyCodeObject, 
                globals: PyDictObject,
                closure: PyObject = nil): PyFuncObject = 
  result = newPyFuncSimple()
  result.name = name
  result.code = code
  result.globals = globals
  if not closure.isNil:
    assert closure.ofPyTupleObject()
  result.closure = PyTupleObject(closure)

