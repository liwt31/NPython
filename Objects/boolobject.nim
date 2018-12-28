import strformat
import macros

import pyobject
import stringobject
import boolobjectBase

method `$`*(obj: PyBoolObject): string = 
  $obj.b

macro implBoolUnary(methodName, code:untyped): untyped = 
  impleUnary(methodName, ident("PyBoolObject"), code)


macro implBoolBinary(methodName, code:untyped): untyped = 
  impleBinary(methodName, ident("PyBoolObject"), code)


implBoolUnary Not:
  if self == pyTrueObj:
    pyFalseObj
  else:
    pyTrueObj


implBoolUnary bool:
  self


implBoolBinary eq:
  let otherBoolObj = other.callMagic(bool)
  if not (otherBoolObj of PyBoolObject):
    return newTypeError(fmt"__bool__ should return bool, got {otherBoolObj.pyType.name}")
  let otherBool = PyBoolObject(otherBoolObj).b
  if self.b == otherBool:
    return pyTrueObj
  else:
    return pyFalseObj
  

implBoolUnary str:
  if self.b:
    return newPyString("True")
  else:
    return newPyString("False")

implBoolUnary repr:
  strPyBoolObject(self)


