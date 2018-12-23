import strutils
import macros
import math

import pyobject
import intobject


type
  PyFloatObject = ref object of PyObject
    v: float64


method `$`*(f: PyFloatObject): string = 
  $f.v


proc newPyFloat: PyFloatObject
proc newPyFloat*(pyObj: PyObject): PyFloatObject
proc newPyFloat(v: float): PyFloatObject


macro impleFloatUnary(methodName, code:untyped): untyped = 
  result = impleUnary(methodName, ident("PyFloatObject"), code)


macro impleFloatBinary(methodName, code:untyped): untyped = 
  result = impleBinary(methodName, ident("PyFloatObject"), code)


let pyFloatObjectType = new PyTypeObject



impleFloatBinary add:
  if other of PyFloatObject:
    result = newPyFloat(self.v + PyFloatObject(other).v)
  else:
    let otherFloat = newPyFloat(other)
    result = addPyFloatObject(self, other)


impleFloatBinary subtract:
  if other of PyFloatObject:
    result = newPyFloat(self.v - PyFloatObject(other).v)
  else:
    let otherFloat = newPyFloat(other)
    result = subtractPyFloatObject(self, other)


impleFloatBinary multiply:
  if other of PyFloatObject:
    result = newPyFloat(self.v * PyFloatObject(other).v)
  else:
    let otherFloat = newPyFloat(other)
    result = multiplyPyFloatObject(self, other)


impleFloatBinary power:
  if other of PyFloatObject:
    result = newPyFloat(self.v.pow PyFloatObject(other).v)
  else:
    let otherFloat = newPyFloat(other)
    result = powerPyFloatObject(self, other)


impleFloatBinary power:
  if other of PyFloatObject:
    result = newPyFloat(self.v.pow PyFloatObject(other).v)
  else:
    let otherFloat = newPyFloat(other)
    result = powerPyFloatObject(self, other)

proc newPyFloat: PyFloatObject = 
  new result
  result.pyType = pyFloatObjectType



proc newPyFloat(pyObj: PyObject): PyFloatObject = 
  if pyObj of PyIntObject:
    result = newPyFloat()
    result.v = parseFloat($pyObj)
  else:
    assert false


proc newPyFloat(v: float): PyFloatObject = 
  result = newPyFloat()
  result.v = v

