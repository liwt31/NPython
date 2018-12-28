import tables
import macros
import strformat
import strutils
import math

import bigints

import pyobject
import boolobject
import stringobject
import ../Utils/utils


type 
  PyIntObject* = ref object of PyObject
    v: BigInt

  PyFloatObject = ref object of PyObject
    v: float64


method `$`*(i: PyIntObject): string = 
  $i.v


method `$`*(f: PyFloatObject): string = 
  $f.v

# currently see no need for an abstract layer to do type casting
# not much gain and decreases readability

proc newPyInt: PyIntObject
proc newPyInt*(n: BigInt): PyIntObject
proc newPyInt*(str: string): PyIntObject

proc newPyFloat: PyFloatObject
proc newPyFloat*(pyInt: PyIntObject): PyFloatObject
proc newPyFloat*(v: float): PyFloatObject


template intBinaryTemplate(op, methodName: untyped, methodNameStr:string) = 
  if other of PyIntObject:
    result = newPyInt(self.v.op PyIntObject(other).v)
  elif other of PyFloatObject:
    result = newPyFloat(self).callMagic(methodName, other)
  else:
    result = newTypeError(methodnameStr & fmt" not supported by int and {other.pyType.name}")

# the macros will assert the type of the first argument
# cast the first argument to corresponding type
# and add the resulting method to type object
macro impleIntUnary(methodName, code:untyped): untyped = 
  result = impleUnary(methodName, ident("PyIntObject"), code)

macro impleIntBinary(methodName, code:untyped): untyped = 
  result = impleBinary(methodName, ident("PyIntObject"), code)

template unsupportedType = 
  assert false


let pyIntObjectType* = newPyType("int")


let pyFloatObjectType* = newPyType("float")


impleIntBinary add:
  intBinaryTemplate(`+`, add, "+")


impleIntBinary subtract:
  intBinaryTemplate(`-`, subtract, "-")


impleIntBinary multiply:
  intBinaryTemplate(`*`, multiply, "*")


impleIntBinary trueDivide:
  let casted = newPyFloat(self)
  casted.callMagic(trueDivide, other)


impleIntBinary floorDivide:
  intBinaryTemplate(`div`, floorDivide, "//")


impleIntBinary power:
  intBinaryTemplate(pow, power, "**")


impleIntUnary positive:
  self

impleIntUnary negative: 
  newPyInt(-self.v)


impleIntUnary bool:
  if self.v == 0:
    pyFalseObj
  else:
    pyTrueObj


impleIntBinary lt:
  if other of PyIntObject:
    if self.v < PyIntObject(other).v:
      result = pyTrueObj
    else:
      result = pyFalseObj
  elif other of PyFloatObject:
    result = other.callMagic(ge, self)
  else:
    unsupportedType


impleIntBinary eq:
  assert other of PyIntObject
  if self.v == PyIntObject(other).v:
    pyTrueObj
  else:
    pyFalseObj


impleIntUnary str:
  newPyString($self)


impleIntUnary repr:
  newPyString($self)


macro impleFloatUnary(methodName, code:untyped): untyped = 
  result = impleUnary(methodName, ident("PyFloatObject"), code)


template floatCastType(methodName: string) = 
  var casted {. inject .} : PyFloatObject
  if other of PyFloatObject:
    casted = PyFloatObject(other)
  elif other of PyIntObject:
    casted = newPyFloat(PyIntObject(other))
  else:
    let msg = methodName & fmt" not supported by float and {other.pyType.name}"
    return newTypeError(msg)

macro impleFloatBinary(methodName, code:untyped): untyped = 
  let castType = getAst(floatCastType(methodName.strVal))
  let imple = newStmtList(castType, code)
  result = impleBinary(methodName, ident("PyFloatObject"), imple)


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


impleFloatUnary positive:
  self

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


impleFloatUnary str:
  newPyString($self)


impleFloatUnary repr:
  newPyString($self)


proc newPyInt: PyIntObject = 
  new result
  result.pyType = pyIntObjectType


proc newPyInt*(n: BigInt): PyIntObject = 
  result = newPyInt()
  result.v = n


proc newPyInt*(str: string): PyIntObject = 
  result = newPyInt()
  result.v = str.initBigInt


proc newPyInt*(i: int): PyIntObject = 
  result = newPyInt()
  result.v = i.initBigInt


proc newPyFloat: PyFloatObject = 
  new result
  result.pyType = pyFloatObjectType


proc newPyFloat(pyInt: PyIntObject): PyFloatObject = 
  result = newPyFloat()
  result.v = parseFloat($pyInt) # a stupid workaround...todo: make reasonable one


proc newPyFloat(v: float): PyFloatObject = 
  result = newPyFloat()
  result.v = v

