import tables
import hashes
import parseutils
import macros
import strformat
import strutils
import math

import bigints

import pyobject
import exceptions
import boolobject
import stringobject
import ../Utils/utils


declarePyType Int(tpToken):
  v: BigInt

declarePyType Float(tpToken):
  v: float

method `$`*(i: PyIntObject): string = 
  $i.v


method `$`*(f: PyFloatObject): string = 
  $f.v

# let's see how long I can stand with these 2 stupid workarounds.
proc toInt*(pyInt: PyIntObject): int = 
  # XXX: take care of overflow error, usually this is used for indexing
  # so builtin int which is the return type of seq.len should be enough
  parseInt($pyInt)

proc toFloat*(pyInt: PyIntObject): float = 
  parseFloat($pyInt)


proc newPyInt*(n: BigInt): PyIntObject = 
  result = newPyIntSimple()
  result.v = n


proc newPyInt*(str: string): PyIntObject = 
  result = newPyIntSimple()
  result.v = str.initBigInt


proc newPyInt*(i: int): PyIntObject = 
  result = newPyIntSimple()
  result.v = i.initBigInt


proc newPyFloat*(pyInt: PyIntObject): PyFloatObject = 
  result = newPyFloatSimple()
  result.v = pyInt.toFloat 


proc newPyFloat*(v: float): PyFloatObject = 
  result = newPyFloatSimple()
  result.v = v


template intBinaryTemplate(op, methodName: untyped, methodNameStr:string) = 
  if other.ofPyIntObject:
    result = newPyInt(self.v.op PyIntObject(other).v)
  elif other.ofPyFloatObject:
    let newFloat = newPyFloat(self)
    result = newFloat.callMagic(methodName, other)
  else:
    result = newTypeError(methodnameStr & fmt" not supported by int and {other.pyType.name}")


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
  if other.ofPyIntObject:
    if self.v < PyIntObject(other).v:
      result = pyTrueObj
    else:
      result = pyFalseObj
  elif other.ofPyFloatObject:
    result = other.callMagic(ge, self)
  else:
    result = newTypeError(fmt"< not supported by int and {other.pyType.name}")


implIntBinary eq:
  if other.ofPyIntObject:
    if self.v == PyIntObject(other).v:
      result = pyTrueObj
    else:
      result = pyFalseObj
  elif other.ofPyFloatObject:
    result = other.callMagic(eq, self)
  elif other.ofPyBoolObject:
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


implIntUnary hash:
  self

template castOtherTypeTmpl(methodName) = 
  var casted {. inject .} : PyFloatObject
  if other.ofPyFloatObject:
    casted = PyFloatObject(other)
  elif other.ofPyIntObject:
    casted = newPyFloat(PyIntObject(other))
  else:
    let msg = methodName & fmt" not supported by float and {other.pyType.name}"
    return newTypeError(msg)

macro castOther(code:untyped):untyped = 
  let fullName = code.name.strVal
  let d = fullName.skipUntil('P') # add'P'yFloatObj, luckily there's no 'P' in magics
  let methodName = fullName[0..<d]
  code.body = newStmtList(
    getAst(castOtherTypeTmpl(methodName)),
    code.body
  )
  code


implFloatBinary add, [castOther]:
  newPyFloat(self.v + casted.v)


implFloatBinary subtract, [castOther]:
  newPyFloat(self.v - casted.v)


implFloatBinary multiply, [castOther]:
  newPyFloat(self.v * casted.v)


implFloatBinary trueDivide, [castOther]:
  newPyFloat(self.v / casted.v)


implFloatBinary floorDivide, [castOther]:
  newPyFloat(floor(self.v / casted.v))


implFloatBinary power, [castOther]:
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


implFloatBinary lt, [castOther]:
  if self.v < casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


implFloatBinary eq, [castOther]:
  if self.v == casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


implFloatBinary gt, [castOther]:
  if self.v > casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


implFloatUnary str:
  newPyString($self)


implFloatUnary repr:
  newPyString($self)

implFloatUnary hash:
  newPyInt(hash(self.v))

