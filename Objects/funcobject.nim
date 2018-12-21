import pyobject
import codeobject
import stringobject

type
  PyFunctionObject* = ref object of PyObject
    name*: PyStringObject
    code*: PyCodeObject


proc newPyFunction*(name: PyStringObject, code: PyCodeObject): PyFunctionObject = 
  result = new PyFunctionObject
  result.name = name
  result.code = code

