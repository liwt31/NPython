import strformat
import macros

import pyobject
import stringobject
import boolobject

method `$`*(obj: PyBoolObject): string = 
  $obj.b

macro implBoolUnary(methodName, code:untyped): untyped = 
  implUnary(methodName, ident("PyBoolObject"), code)


macro implBoolBinary(methodName, code:untyped): untyped = 
  implBinary(methodName, ident("PyBoolObject"), code)


implBoolUnary Not:
  if self == pyTrueObj:
    pyFalseObj
  else:
    pyTrueObj


implBoolUnary bool:
  self


implBoolBinary And:
  let otherBoolObj = other.callMagic(bool)
  errorIfNotBool(otherBoolObj, "__bool__")
  if self.b and PyBoolObject(otherBoolObj).b:
    return pyTrueObj
  else:
    return pyFalseObj

implBoolBinary Xor:
  let otherBoolObj = other.callMagic(bool)
  errorIfNotBool(otherBoolObj, "__bool__")
  if self.b xor PyBoolObject(otherBoolObj).b:
    return pyTrueObj
  else:
    return pyFalseObj

implBoolBinary Or:
  let otherBoolObj = other.callMagic(bool)
  errorIfNotBool(otherBoolObj, "__bool__")
  if self.b or PyBoolObject(otherBoolObj).b:
    return pyTrueObj
  else:
    return pyFalseObj

implBoolBinary eq:
  let otherBoolObj = other.callMagic(bool)
  errorIfNotBool(otherBoolObj, "__bool__")
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

