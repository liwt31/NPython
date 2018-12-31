import pyobject
import codeobject
import stringobject
import dictobject

declarePyType Function():
  name: PyStrObject
  code: PyCodeObject
  globals: PyDictObject


proc newPyFunction*(name: PyStrObject, 
                    code: PyCodeObject, 
                    globals: PyDictObject): PyFunctionObject = 
  result = new PyFunctionObject
  result.name = name
  result.code = code
  result.globals = globals

