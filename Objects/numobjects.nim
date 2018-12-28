import tables
import macros
import strformat
import strutils
import math

import bigints

import pyobject
import boolobjectBase
import stringobject
import ../Utils/utils


type 
  PyIntObject* = ref object of PyObject
    v*: BigInt

  PyFloatObject = ref object of PyObject
    v*: float64


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
macro implIntUnary(methodName, code:untyped): untyped = 
  result = implUnary(methodName, ident("PyIntObject"), code)

macro implIntBinary(methodName, code:untyped): untyped = 
  result = implBinary(methodName, ident("PyIntObject"), code)

template unsupportedType = 
  assert false


let pyIntObjectType* = newPyType("int")


let pyFloatObjectType* = newPyType("float")


implIntBinary add:
  intBinaryTemplate(`+`, add, "+")


implIntBinary subtract:
  intBinaryTemplate(`-`, subtract, "-")


implIntBinary multiply:
  intBinaryTemplate(`*`, multiply, "*")


implIntBinary trueDivide:
  let casted = newPyFloat(self)
  casted.callMagic(trueDivide, other)


implIntBinary floorDivide:
  intBinaryTemplate(`div`, floorDivide, "//")


implIntBinary power:
  intBinaryTemplate(pow, power, "**")


implIntUnary positive:
  self

implIntUnary negative: 
  newPyInt(-self.v)


implIntUnary bool:
  if self.v == 0:
    pyFalseObj
  else:
    pyTrueObj


implIntBinary lt:
  if other of PyIntObject:
    if self.v < PyIntObject(other).v:
      result = pyTrueObj
    else:
      result = pyFalseObj
  elif other of PyFloatObject:
    result = other.callMagic(ge, self)
  else:
    result = newTypeError(fmt"< not supported by int and {other.pyType.name}")


implIntBinary eq:
  if other of PyIntObject:
    if self.v == PyIntObject(other).v:
      result = pyTrueObj
    else:
      result = pyFalseObj
  elif other of PyFloatObject:
    result = other.callMagic(eq, self)
  elif other of PyBoolObject:
    if self.v == 1:
      result = other
    else:
      result = other.callMagic(Not)
  else:
    result = newTypeError(fmt"== not supported by int and {other.pyType.name}")



implIntUnary str:
  newPyString($self)


implIntUnary repr:
  newPyString($self)


macro implFloatUnary(methodName, code:untyped): untyped = 
  result = implUnary(methodName, ident("PyFloatObject"), code)


template floatCastType(methodName: string) = 
  var casted {. inject .} : PyFloatObject
  if other of PyFloatObject:
    casted = PyFloatObject(other)
  elif other of PyIntObject:
    casted = newPyFloat(PyIntObject(other))
  else:
    let msg = methodName & fmt" not supported by float and {other.pyType.name}"
    return newTypeError(msg)

macro implFloatBinary(methodName, code:untyped): untyped = 
  let castType = getAst(floatCastType(methodName.strVal))
  let impl = newStmtList(castType, code)
  result = implBinary(methodName, ident("PyFloatObject"), impl)


implFloatBinary add:
  newPyFloat(self.v + casted.v)


implFloatBinary subtract:
  newPyFloat(self.v - casted.v)


implFloatBinary multiply:
  newPyFloat(self.v * casted.v)


implFloatBinary trueDivide:
  newPyFloat(self.v / casted.v)


implFloatBinary floorDivide:
  newPyFloat(floor(self.v / casted.v))


implFloatBinary power:
  newPyFloat(self.v.pow(casted.v))


implFloatUnary positive:
  self

implFloatUnary negative:
  newPyFloat(-self.v)


implFloatUnary bool:
  if self.v == 0:
    return pyFalseObj
  else:
    return pyTrueObj


implFloatBinary lt:
  if self.v < casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


implFloatBinary eq:
  if self.v == casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


implFloatBinary gt:
  if self.v > casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


implFloatUnary str:
  newPyString($self)


implFloatUnary repr:
  newPyString($self)

# let's see how long I can tolerant these 2 stupid workarounds.
proc toInt*(pyInt: PyIntObject): int = 
  # XXX: take care of overflow error, usually this is used for indexing
  # so builtin int which is the return type of seq.len should be enough
  parseInt($pyInt)

proc toFloat*(pyInt: PyIntObject): float = 
  parseFloat($pyInt)

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
  result.v = pyInt.toFloat 


proc newPyFloat(v: float): PyFloatObject = 
  result = newPyFloat()
  result.v = v

