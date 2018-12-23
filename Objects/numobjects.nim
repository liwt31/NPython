import tables
import strutils
import macros
import math

import bigints

import pyobject
import boolobject
import ../Utils/utils


type 
  PyIntObject* = ref object of PyObject
    n: BigInt

  PyFloatObject = ref object of PyObject
    v: float64


method `$`*(pyInt: PyIntObject): string = 
  $pyInt.n


method `$`*(f: PyFloatObject): string = 
  $f.v

# currently see no need for an abstract layer to do type casting
# not much gain and decreases readability

proc newPyInt: PyIntObject
proc newPyInt*(n: BigInt): PyIntObject
proc newPyInt*(str: string): PyIntObject

proc newPyFloat: PyFloatObject
proc newPyFloat*(pyObj: PyObject): PyFloatObject
proc newPyFloat(v: float): PyFloatObject

proc subtractPyFloatObject(selfNoCast, other: PyObject): PyObject
proc powerPyFloatObject(selfNoCast, other: PyObject): PyObject
proc trueDividePyFloatObject(selfNoCast, other: PyObject): PyObject
proc floorDividePyFloatObject(selfNoCast, other: PyObject): PyObject

# the macros will assert the type of the first argument
# cast the first argument to corresponding type
# and add the resulting method to type object
macro impleIntUnary(methodName, code:untyped): untyped = 
  result = impleUnary(methodName, ident("PyIntObject"), code)


macro impleIntBinary(methodName, code:untyped): untyped = 
  result = impleBinary(methodName, ident("PyIntObject"), code)


macro impleFloatUnary(methodName, code:untyped): untyped = 
  result = impleUnary(methodName, ident("PyFloatObject"), code)


template castType = 
  var casted {. inject .} : PyFloatObject
  if other of PyFloatObject:
    casted = PyFloatObject(other)
  else:
    casted = newPyFloat(other)

macro impleFloatBinary(methodName, code:untyped): untyped = 
  let castType = getAst(castType())
  let imple = newStmtList(castType, code)
  result = impleBinary(methodName, ident("PyFloatObject"), imple)


template unsupportedType = 
  assert false


let pyIntObjectType = newPyType("int")


let pyFloatObjectType = newPyType("float")


impleIntBinary add:
  if other of PyIntObject:
    result = newPyInt(self.n + PyIntObject(other).n)
  elif other of PyFloatObject:
    result = other.call(add, self)
  else:
    unsupportedType


impleIntBinary subtract:
  if other of PyIntObject:
    result = newPyInt(self.n - PyIntObject(other).n)
  elif other of PyFloatObject:
    result = subtractPyFloatObject(newPyFloat(self), other)
  else:
    unsupportedType


impleIntBinary multiply:

  if other of PyIntObject:
    result = newPyInt(self.n * PyIntObject(other).n)
  elif other of PyFloatObject:
    result = other.call(multiply, self)
  else:
    unsupportedType


impleIntBinary trueDivide:
  let casted = newPyFloat(self)
  trueDividePyFloatObject(casted, other)


impleIntBinary floorDivide:
  if other of PyIntObject:
    result = newPyInt(self.n.div PyIntObject(other).n)
  elif other of PyFloatObject:
    result = floorDividePyFloatObject(newPyFloat(self), other)
  else:
    unsupportedType

impleIntBinary power:
  if other of PyIntObject:
    result = newPyInt(self.n.pow PyIntObject(other).n)
  elif other of PyFloatObject:
    result = powerPyFloatObject(newPyFloat(self), other)
  else:
    unsupportedType


impleIntUnary negative: 
  newPyInt(-self.n)


impleIntUnary bool:
  if self.n == 0:
    pyFalseObj
  else:
    pyTrueObj


impleIntBinary lt:
  if other of PyIntObject:
    if self.n < PyIntObject(other).n:
      result = pyTrueObj
    else:
      result = pyFalseObj
  elif other of PyFloatObject:
    result = other.call(ge, self)
  else:
    assert false


impleIntBinary eq:
  assert other of PyIntObject
  if self.n == PyIntObject(other).n:
    pyTrueObj
  else:
    pyFalseObj



impleFloatBinary add:
  newPyFloat(self.v + casted.v)


impleFloatBinary subtract:
  newPyFloat(self.v - casted.v)


impleFloatBinary multiply:
  newPyFloat(self.v * casted.v)


impleFloatBinary trueDivide:
  newPyFloat(self.v / casted.v)


impleFloatBinary floorDivide:
  newPyFloat(floor(self.v / casted.v))


impleFloatBinary power:
  newPyFloat(self.v.pow(casted.v))


impleFloatUnary negative:
  newPyFloat(-self.v)


impleFloatUnary bool:
  if self.v == 0:
    return pyFalseObj
  else:
    return pyTrueObj


impleFloatBinary lt:
  if self.v < casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


impleFloatBinary eq:
  if self.v == casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


impleFloatBinary gt:
  if self.v > casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


proc newPyInt: PyIntObject = 
  new result
  result.pyType = pyIntObjectType


proc newPyInt*(n: BigInt): PyIntObject = 
  result = newPyInt()
  result.n = n


proc newPyInt*(str: string): PyIntObject = 
  result = newPyInt()
  result.n = str.initBigInt


proc newPyFloat: PyFloatObject = 
  new result
  result.pyType = pyFloatObjectType


proc newPyFloat(pyObj: PyObject): PyFloatObject = 
  if pyObj of PyIntObject:
    result = newPyFloat()
    result.v = parseFloat($pyObj) # a stupid workaround...
  else:
    unsupportedType


proc newPyFloat(v: float): PyFloatObject = 
  result = newPyFloat()
  result.v = v

