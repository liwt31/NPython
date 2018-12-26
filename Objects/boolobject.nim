import macros

import pyobject

type
  PyBoolObject = ref object of PyObject
    b: bool


let pyBoolObjectType = newPyType("bool")


proc newPyBool(b: bool): PyBoolObject = 
  result = new PyBoolObject
  result.pyType = pyBoolObjectType
  result.b = b


let pyTrueObj* = newPyBool(true)
let pyFalseObj* = newPyBool(false)


method `$`*(obj: PyBoolObject): string = 
  $obj.b

macro impleBoolUnary(methodName, code:untyped): untyped = 
  impleUnary(methodName, ident("PyBoolObject"), code)


macro impleBoolBinary(methodName, code:untyped): untyped = 
  impleBinary(methodName, ident("PyBoolObject"), code)


impleBoolUnary Not:
  if self == pyTrueObj:
    pyFalseObj
  else:
    pyTrueObj


impleBoolUnary bool:
  self


