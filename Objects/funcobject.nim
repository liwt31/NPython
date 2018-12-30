import pyobject
import codeobject
import stringobject

type
  PyFunctionObject* = ref object of PyObject
    name*: PyStrObject
    code*: PyCodeObject


proc newPyFunction*(name: PyStrObject, code: PyCodeObject): PyFunctionObject = 
  result = new PyFunctionObject
  result.name = name
  result.code = code

