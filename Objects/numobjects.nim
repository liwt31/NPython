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
    let msg = methodnameStr & fmt" not supported by int and {other.pyType.name}"
    result = newTypeError(msg)


implIntMagic add:
  intBinaryTemplate(`+`, add, "+")


implIntMagic sub:
  intBinaryTemplate(`-`, sub, "-")


implIntMagic mul:
  intBinaryTemplate(`*`, mul, "*")


implIntMagic trueDiv:
  let casted = newPyFloat(self)
  casted.callMagic(trueDiv, other)


implIntMagic floorDiv:
 if other.ofPyIntObject:
   let intOther = PyIntObject(other)
   if intOther.v == 0:
     return newZeroDivisionError()
   result = newPyInt(self.v.div PyIntObject(other).v)
 elif other.ofPyFloatObject:
   let newFloat = newPyFloat(self)
   result = newFloat.callMagic(floorDiv, other)
 else:
   result = newTypeError(fmt"floor divide not supported by int and {other.pyType.name}")


implIntMagic pow:
  intBinaryTemplate(pow, pow, "**")


implIntMagic positive:
  self

implIntMagic negative: 
  newPyInt(-self.v)


implIntMagic bool:
  if self.v == 0:
    pyFalseObj
  else:
    pyTrueObj


implIntMagic lt:
  if other.ofPyIntObject:
    if self.v < PyIntObject(other).v:
      result = pyTrueObj
    else:
      result = pyFalseObj
  elif other.ofPyFloatObject:
    result = other.callMagic(ge, self)
  else:
    let msg = fmt"< not supported by int and {other.pyType.name}"
    result = newTypeError(msg)


implIntMagic eq:
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
    let msg = fmt"== not supported by int and {other.pyType.name}"
    result = newTypeError(msg)


implIntMagic str:
  newPyString($self)


implIntMagic repr:
  newPyString($self)


implIntMagic hash:
  self

implIntMagic New:
  checkArgNum(2)
  let arg = args[1]
  case arg.pyType.kind
  of PyTypeToken.Int:
    return arg
  of PyTypeToken.Float:
    let iStr = $cast[PyFloatObject](arg).v
    return newPyInt(iStr.split(".")[0])
  of PyTypeToken.Str:
    let str = cast[PyStrObject](arg).str
    try:
      return newPyInt(str)
    except ValueError:
      let msg = fmt"invalid literal for int() with base 10: '{str}'"
      return newValueError(msg)
  of PyTypeToken.Bool:
    if cast[PyBoolObject](arg).b:
      return newPyInt(1)
    else:
      return newPyInt(0)
  else:
    return newTypeError(fmt"Int argument can't be '{arg.pyType.name}'")

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


implFloatMagic add, [castOther]:
  newPyFloat(self.v + casted.v)


implFloatMagic sub, [castOther]:
  newPyFloat(self.v - casted.v)


implFloatMagic mul, [castOther]:
  newPyFloat(self.v * casted.v)


implFloatMagic trueDiv, [castOther]:
  newPyFloat(self.v / casted.v)


implFloatMagic floorDiv, [castOther]:
  newPyFloat(floor(self.v / casted.v))


implFloatMagic pow, [castOther]:
  newPyFloat(self.v.pow(casted.v))


implFloatMagic positive:
  self

implFloatMagic negative:
  newPyFloat(-self.v)


implFloatMagic bool:
  if self.v == 0:
    return pyFalseObj
  else:
    return pyTrueObj


implFloatMagic lt, [castOther]:
  if self.v < casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


implFloatMagic eq, [castOther]:
  if self.v == casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


implFloatMagic gt, [castOther]:
  if self.v > casted.v:
    return pyTrueObj
  else:
    return pyFalseObj


implFloatMagic str:
  newPyString($self)


implFloatMagic repr:
  newPyString($self)

implFloatMagic hash:
  newPyInt(hash(self.v))



# used in list and tuple
template getIndex*(obj: PyIntObject, size: int): int = 
  # todo: if overflow, then thrown indexerror
  var idx = obj.toInt
  if idx < 0:
    idx = size + idx
  if (idx < 0) or (size <= idx):
    let msg = "index out of range. idx: " & $idx & ", len: " & $size
    return newIndexError(msg)
  idx

