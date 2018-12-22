import tables
import macros

import bigints

import pyobject
import boolobject
import ../Utils/utils


type 
  PyIntObject = ref object of PyObject
    n: BigInt


method `$`*(pyInt: PyIntObject): string = 
  $pyInt.n


# some attempts to make common int cheaper
# seems like a premature optimization

#[
const intCacheSize = 10

var intCache: array[intCacheSize, PyIntObject]
for i in 0..<intCacheSize:
  let pyInt = new PyIntObject
  pyInt.n = i.initBigInt
  intCache[i] = pyInt

]#

proc newPyInt: PyIntObject
proc newPyInt*(n: BigInt): PyIntObject
proc newPyInt*(str: string): PyIntObject

# the macros will assert the type of the first argument
# cast the first argument to PyIntObject
# and add the resulting method to pyIntObjectType
macro impleIntUnary(methodName, code:untyped): untyped = 
  result = impleUnary(methodName, ident("PyIntObject"), code)

macro impleIntBinary(methodName, code:untyped): untyped = 
  result = impleBinary(methodName, ident("PyIntObject"), code)


let pyIntObjectType = new PyTypeObject

impleIntBinary add:
  assert other of PyIntObject
  # should do some cast like int->float when float is implemented
  newPyInt(self.n + PyIntObject(other).n)

impleIntBinary substract:
  assert other of PyIntObject
  newPyInt(self.n - PyIntObject(other).n)

impleIntBinary multiply:
  assert other of PyIntObject
  newPyInt(self.n * PyIntObject(other).n)

impleIntBinary power:
  assert other of PyIntObject
  newPyInt(self.n.pow PyIntObject(other).n )


impleIntUnary negative: 
  newPyInt(-self.n)


impleIntUnary bool:
  if self.n == 0:
    return pyFalseObj
  else:
    return pyTrueObj


impleIntBinary inplaceAdd:
  assert other of PyIntObject
  self.n = self.n + PyIntObject(other).n


impleIntBinary inplaceSubtract:
  assert other of PyIntObject
  self.n = self.n - PyIntObject(other).n


impleIntBinary lt:
  assert other of PyIntObject
  if self.n < PyIntObject(other).n:
    return pyTrueObj
  else:
    return pyFalseObj

impleIntBinary eq:
  assert other of PyIntObject
  if self.n == PyIntObject(other).n:
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


when isMainModule:
  let n = newPyInt("6666666666666666666")
  echo n

