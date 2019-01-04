import strformat
import hashes
import macros

import pyobject
import exceptions
import stringobject
import boolobject
import numobjects

export boolobject

method `$`*(obj: PyBoolObject): string = 
  $obj.b

methodMacroTmpl(Bool, "Bool")

implBoolUnary Not:
  if self == pyTrueObj:
    pyFalseObj
  else:
    pyTrueObj


implBoolUnary bool:
  self


# failed to use template because `and` etc. are keywords...
implBoolBinary And:
  let otherBoolObj = other.callMagic(bool)
  errorIfNotBool(otherBoolObj, "__bool__")
  if self.b and cast[PyBoolObject](otherBoolObj).b:
    return pyTrueObj
  else:
    return pyFalseObj

implBoolBinary Xor:
  let otherBoolObj = other.callMagic(bool)
  errorIfNotBool(otherBoolObj, "__bool__")
  if self.b xor cast[PyBoolObject](otherBoolObj).b:
    return pyTrueObj
  else:
    return pyFalseObj

implBoolBinary Or:
  let otherBoolObj = other.callMagic(bool)
  errorIfNotBool(otherBoolObj, "__bool__")
  if self.b or cast[PyBoolObject](otherBoolObj).b:
    return pyTrueObj
  else:
    return pyFalseObj

implBoolBinary eq:
  let otherBoolObj = other.callMagic(bool)
  errorIfNotBool(otherBoolObj, "__bool__")
  let otherBool = cast[PyBoolObject](otherBoolObj).b
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


implBoolUnary hash:
  newPyInt(Hash(self.b))
