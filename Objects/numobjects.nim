import tables
import algorithm
import hashes
import parseutils
import macros
import strformat
import strutils
import math

#import bigints

import pyobject
import exceptions
import boolobject
import stringobject
import ../Utils/utils

# this is a **very slow** bigint lib, div support is not complete.
# Why reinvent such a bad wheel?
# because we really need some low level control on our modules
# todo: make it a decent bigint module
const maxDigit = high(uint32)
const mask = uint64(high(uint32))

type IntSign = enum
  Negative = -1
  Zero = 0
  Positive = 1

declarePyType Int(tpToken):
  #v: BigInt
  #v: int
  sign: IntSign
  digits: seq[uint32]

proc newPyInt(i: uint32): PyIntObject
proc newPyInt*(i: int): PyIntObject

# currently avoid using setLen because of gh-10651
proc setXLen(intObj: PyIntObject, l: int) =
  if intObj.digits.len == 0:
    intObj.digits = newSeq[uint32](l)
  else:
    intObj.digits.setLen(l)

let pyIntZero* = newPyInt(0'u32)
let pyIntOne* = newPyInt(1'u32)
let pyIntTwo = newPyInt(2'u32)
let pyIntTen* = newPyInt(10'u32)

proc negative*(intObj: PyIntObject): bool {. inline .} =
  intObj.sign == Negative

proc zero*(intObj: PyIntObject): bool {. inline .} =
  intObj.sign == Zero

proc positive*(intObj: PyIntObject): bool {. inline .} =
  intObj.sign == Positive

proc copy(intObj: PyIntObject): PyIntObject =
  let newInt = newPyIntSimple()
  newInt.digits = intObj.digits
  newInt

proc normalize(a: PyIntObject) =
  for i in 0..<a.digits.len:
    if a.digits[^1] == 0:
      discard a.digits.pop()
    else:
      break

# assuming all positive, return a - b
proc doCompare(a, b: PyIntObject): IntSign {. cdecl .} =
  if a.digits.len < b.digits.len:
    return Negative
  if a.digits.len > b.digits.len:
    return Positive
  for i in countdown(a.digits.len-1, 0):
    let ad = a.digits[i]
    let bd = b.digits[i]
    if ad < bd:
      return Negative
    elif ad == bd:
      continue
    else:
      return Positive
  return Zero


proc inplaceAdd(a: PyIntObject, b: uint32) =
  var carry = uint64(b)
  for i in 0..<a.digits.len:
    if carry == 0:
      return
    carry += uint64(a.digits[i])
    a.digits[i] = uint32(carry)
    carry = carry shr 32
  if 0'u64 < carry:
    a.digits.add uint32(carry)


proc doAdd(a, b: PyIntObject): PyIntObject =
  if a.digits.len < b.digits.len:
    return doAdd(b, a)
  var carry = 0'u64
  result = newPyIntSimple()
  for i in 0..<a.digits.len:
    if i < b.digits.len:
      carry += uint64(b.digits[i])
    carry += uint64(a.digits[i])
    result.digits.add uint32(carry)
    carry = carry shr 32
  if 0'u64 < carry:
    result.digits.add uint32(carry)

# assuming all positive, return a - b
proc doSub(a, b: PyIntObject): PyIntObject =
  if a.digits.len < b.digits.len:
    let c = doSub(b, a)
    c.sign = Negative
    return c
  var carry: int64 = 0
  result = newPyIntSimple()
  for i in 0..<a.digits.len:
    if i < b.digits.len:
      carry -= int64(b.digits[i])
    carry += int64(a.digits[i])
    if 0 <= carry:
      result.digits.add uint32(carry)
      carry = 0
    else:
      result.digits.add uint32(int64(maxDigit) + carry + 1)
      carry = -1
  if carry != 0:
    result.digits.add uint32(int64(maxDigit) + carry + 1)
    result.sign = Negative
  result.normalize()
  if result.digits.len == 0:
    result.sign = Zero
  else:
    result.sign = Positive


# assuming all positive, return a * b
proc doMul(a: PyIntObject, b: uint32): PyIntObject =
  result = newPyIntSimple()
  var carry: uint64 = 0
  for i in 0..<a.digits.len:
    carry += uint64(a.digits[i]) * uint64(b)
    result.digits.add uint32(carry)
    carry = carry shr 32
  if 0'u64 < carry:
    result.digits.add uint32(carry)
  
proc doMul(a, b: PyIntObject): PyIntObject =
  var ints: seq[PyIntObject]
  for i, db in b.digits:
    let c = a.doMul(db)
    let zeros = newSeq[uint32](i)
    c.digits = zeros & c.digits
    ints.add c
  result = ints[0]
  for intObj in ints[1..^1]:
    result = result.doAdd(intObj)

proc `<`*(a, b: PyIntObject): bool =
  case a.sign
  of Negative:
    case b.sign
    of Negative:
      return doCompare(a, b) == Positive
    of Zero, Positive:
      return true
  of Zero:
    return b.sign == Positive
  of Positive:
    case b.sign
    of Negative, Zero:
      return false
    of Positive:
      return doCompare(a, b) == Negative

proc `<`*(aa: int, b: PyIntObject): bool =
  let a = newPyInt(aa)
  case a.sign
  of Negative:
    case b.sign
    of Negative:
      return doCompare(a, b) == Positive
    of Zero, Positive:
      return true
  of Zero:
    return b.sign == Positive
  of Positive:
    case b.sign
    of Negative, Zero:
      return false
    of Positive:
      return doCompare(a, b) == Negative

proc `==`*(a, b: PyIntObject): bool =
  if a.sign != b.sign:
    return false
  return doCompare(a, b) == Zero

proc `+`*(a, b: PyIntObject): PyIntObject =
  case a.sign
  of Negative:
    case b.sign
    of Negative:
      let c = doAdd(a, b)
      c.sign = Negative
      return c
    of Zero:
      return a
    of Positive:
      return doSub(a, b)
  of Zero:
    return b
  of Positive:
    case b.sign
    of Negative:
      return doSub(a, b)
    of Zero:
      return a
    of Positive:
      let c = doAdd(a, b)
      c.sign = Positive
      return c

proc `-`*(a, b: PyIntObject): PyIntObject =
  case a.sign
  of Negative:
    case b.sign
    of Negative:
      return doSub(b, a)
    of Zero:
      return a
    of Positive:
      let c = doAdd(a, b)
      c.sign = Negative
      return c
  of Zero:
    case b.sign
    of Negative:
      let c = b.copy()
      c.sign = Positive
      return c
    of Zero:
      return a
    of Positive:
      let c = b.copy()
      c.sign = Negative
      return c
  of Positive:
    case b.sign
    of Negative:
      let c = doAdd(a, b)
      c.sign = Positive
      return c
    of Zero:
      return a
    of Positive:
      return doSub(a, b)

proc `-`*(a: PyIntObject): PyIntObject =
  result = a.copy()
  result.sign = IntSign(-int(a.sign))


proc `*`*(a, b: PyIntObject): PyIntObject =
  case a.sign
  of Negative:
    case b.sign
    of Negative:
      let c = doMul(b, a)
      c.sign = Positive
      return c
    of Zero:
      return pyIntZero
    of Positive:
      let c = doMul(b, a)
      c.sign = Negative
      return c
  of Zero:
    return pyIntZero
  of Positive:
    case b.sign
    of Negative:
      let c = doMul(b, a)
      c.sign = Negative
      return c
    of Zero:
      return pyIntZero
    of Positive:
      let c = doMul(b, a)
      c.sign = Positive
      return c


proc doDiv(n, d: PyIntObject): (PyIntObject, PyIntObject) =
  var
    nn = n.digits.len
    dn = d.digits.len
  assert nn != 0

  if nn < dn:
    return (pyIntZero, n)
  elif dn == 1:
    let dd = d.digits[0]
    let q = newPyIntSimple()
    var rr: uint32
    q.setXLen(n.digits.len)

    for i in countdown(n.digits.high, 0):
      let tmp: uint64 = uint64(n.digits[i]) + uint64(rr) shl 32
      q.digits[i] = uint32(tmp div dd)
      rr = uint32(tmp mod dd)

    q.normalize()
    let r = newPyIntSimple()
    r.digits.add rr
    return (q, r)
  else:
    assert nn >= dn and dn >= 2
    raise newException(IntError, "")


proc `div`*(a, b: PyIntObject): PyIntObject =
  case a.sign
  of Negative:
    case b.sign
    of Negative:
      let (q, r) = doDiv(a, b)
      if q.digits.len == 0:
        q.sign = Zero
      else:
        q.sign = Positive
      return q
    of Zero:
      assert false
    of Positive:
      let (q, r) = doDiv(a, b)
      if q.digits.len == 0:
        q.sign = Zero
      else:
        q.sign = Negative
      return q
  of Zero:
    return pyIntZero
  of Positive:
    case b.sign
    of Negative:
      let (q, r) = doDiv(a, b)
      if q.digits.len == 0:
        q.sign = Zero
      else:
        q.sign = Negative
      return q
    of Zero:
      assert false
    of Positive:
      let (q, r) = doDiv(a, b)
      if q.digits.len == 0:
        q.sign = Zero
      else:
        q.sign = Positive
      return q

# a**b
proc pow(a, b: PyIntObject): PyIntObject =
  assert(not b.negative)
  if b.zero:
    return pyIntOne
  let new_b = b div pyIntTwo
  let half_c = pow(a, new_b)
  if b.digits[0] mod 2 == 1:
    return half_c * half_c * a
  else:
    return half_c * half_c

proc newPyInt(i: uint32): PyIntObject =
  result = newPyIntSimple()
  if i != 0:
    result.digits.add i
  if i == 0:
    result.sign = Zero
  else:
    result.sign = Positive

#[
proc newPyInt(i: int): PyIntObject =
  var ii: int
  if i < 0:
    result = newPyIntSimple()
    result.sign = Negative
    ii = (not i) + 1
  elif i == 0:
    return pyIntZero
  else:
    result = newPyIntSimple()
    result.sign = Positive
    ii = i
  result.digits.add uint32(ii)
  result.digits.add uint32(ii shr 32)
  result.normalize
]#
proc fromStr(s: string): PyIntObject =
  result = newPyIntSimple()
  var start = 0
  var sign: IntSign
  # assume s not empty
  if s[0] == '-':
    start = 1
  result.digits.add 0
  for i in start..<s.len:
    result = result.doMul(10)
    let c = s[i]
    result.inplaceAdd uint32(ord(c) - ord('0'))
  result.normalize
  if s[0] == '-':
    result.sign = Negative
  else:
    if result.digits.len == 0:
      result.sign = Zero
    else:
      result.sign = Positive

method `$`*(i: PyIntObject): string = 
  var strSeq: seq[string]
  if i.zero:
    return "0"
  var ii = i.copy()
  var q: PyIntObject
  while true:
    (ii, q) = ii.doDiv pyIntTen
    strSeq.add($q.digits[0])
    if ii.digits.len == 0:
      break
  #strSeq.add($i.digits)
  if i.negative:
    strSeq.add("-")
  strSeq.reversed.join()

proc hash*(self: PyIntObject): Hash {. inline, cdecl .} = 
  result = hash(self.sign)
  for digit in self.digits:
    result = result xor hash(digit)

declarePyType Float(tpToken):
  v: float

method `$`*(f: PyFloatObject): string = 
  $f.v

proc toInt*(pyInt: PyIntObject): int = 
  # XXX: the caller should take care of overflow
  case pyInt.digits.len
  of 0:
    assert pyInt.zero
    return 0
  of 1:
    result = int(pyInt.digits[0])
  of 2:
    result = int(pyInt.digits[1]) shl 32
    result += int(pyInt.digits[0])
  else:
    unreachable
  if pyInt.sign == Negative:
    result *= -1


proc toFloat*(pyInt: PyIntObject): float = 
  parseFloat($pyInt)


proc newPyInt*(str: string): PyIntObject = 
  fromStr(str)

proc newPyInt*(i: int): PyIntObject = 
  result = newPyIntSimple()
  if i == 0:
    result.sign = Zero
    return
  let ui = abs(i)
  result.digits.add uint32(ui mod int(maxDigit))
  let h = ui div int(maxDigit)
  if h != 0:
    result.digits.add uint32(h)
  if i < 0:
    result.sign = Negative
  else:
    result.sign = Positive


proc newPyFloat*(pyInt: PyIntObject): PyFloatObject = 
  result = newPyFloatSimple()
  result.v = pyInt.toFloat 


proc newPyFloat*(v: float): PyFloatObject = 
  result = newPyFloatSimple()
  result.v = v


template intBinaryTemplate(op, methodName: untyped, methodNameStr:string) = 
  if other.ofPyIntObject:
    #result = newPyInt(self.v.op PyIntObject(other).v)
    result = self.op PyIntObject(other)
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
   if intOther.zero:
     return newZeroDivisionError()
   try:
     return self.div PyIntObject(other)
   except IntError:
     return newValueError("big int operation not implemented")
 elif other.ofPyFloatObject:
   let newFloat = newPyFloat(self)
   return newFloat.callMagic(floorDiv, other)
 else:
   return newTypeError(fmt"floor divide not supported by int and {other.pyType.name}")

implIntMagic pow:
  intBinaryTemplate(pow, pow, "**")


implIntMagic positive:
  self

implIntMagic negative: 
  -self

implIntMagic bool:
  if self.zero:
    pyFalseObj
  else:
    pyTrueObj


implIntMagic lt:
  if other.ofPyIntObject:
    if self < PyIntObject(other):
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
    if self == PyIntObject(other):
      result = pyTrueObj
    else:
      result = pyFalseObj
  elif other.ofPyFloatObject:
    result = other.callMagic(eq, self)
  elif other.ofPyBoolObject:
    if self == pyIntOne:
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


when isMainModule:
  #let a = fromStr("-1234567623984672384623984712834618623")
  #let a = fromStr("3234567890")
  #[
  echo a
  echo a + a
  echo a + a - a
  echo a + a - a - a
  echo a + a - a - a - a
  ]#
  #let a = fromStr("88888888888888")
  let a = fromStr("100000000000")
  echo a.pow(pyIntTen)
  echo a
  #echo a * pyIntTen
  #echo a.pow pyIntTen
  #let a = fromStr("100000000000")
  #echo a
  #echo a * fromStr("7") - a - a - a - a - a - a - a
  #let b = newPyInt(2)
  #echo pyIntTen
  #echo -pyIntTen
  #echo a
  #echo int(a)
  #echo -int(a)
  #echo IntSign(-int(a))
  #echo newPyInt(3).pow(pyIntTwo) - pyIntOne + pyIntTwo
  #echo a div b
  #echo a div b * newPyInt(2)
