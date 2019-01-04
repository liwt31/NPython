import pyobject
import codeobject
import stringobject
import dictobject

declarePyType Func(tpToken):
  name: PyStrObject
  code: PyCodeObject
  globals: PyDictObject


proc newPyFunc*(name: PyStrObject, 
                code: PyCodeObject, 
                globals: PyDictObject): PyFuncObject = 
  result = newPyFuncSimple()
  result.name = name
  result.code = code
  result.globals = globals

