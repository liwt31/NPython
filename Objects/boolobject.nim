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


impleBoolBinary And:
  var casted: PyBoolObject
  if other of PyBoolObject:
    casted = PyBoolObject(other)
  else:
    casted = PyBoolObject(other.call(bool))
  if self.b and casted.b:
    return pyTrueObj
  else:
    return pyFalseObj


impleBoolBinary Xor:
  var casted: PyBoolObject
  if other of PyBoolObject:
    casted = PyBoolObject(other)
  else:
    casted = PyBoolObject(other.call(bool))
  if self.b xor casted.b:
    return pyTrueObj
  else:
    return pyFalseObj


impleBoolBinary Or:
  var casted: PyBoolObject
  if other of PyBoolObject:
    casted = PyBoolObject(other)
  else:
    casted = PyBoolObject(other.call(bool))
  if self.b or casted.b:
    return pyTrueObj
  else:
    return pyFalseObj
