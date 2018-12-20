import tables

import bigints

import pyobject
import boolobject
import Utils/utils


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


template assertType = 
  assert self of PyIntObject
  assert other of PyIntObject

proc addPyInt(self, other: PyObject): PyObject =
  assertType
  # should do some cast like int->float when float is implemented
  newPyInt(PyIntObject(self).n + PyIntObject(other).n)

proc substractPyInt(self, other: PyObject): PyObject = 
  assertType
  newPyInt(PyIntObject(self).n - PyIntObject(other).n)

proc powerPyInt(self, other: PyObject): PyObject = 
  assertType
  newPyInt(PyIntObject(self).n.pow PyIntObject(other).n )

proc boolPyInt(self: PyObject): PyObject = 
  assert self of PyIntObject
  if PyIntObject(self).n == 0:
    return pyFalseObj
  else:
    return pyTrueObj

proc ltPyInt(self, other: PyObject): PyObject = 
  assertType
  if PyIntObject(self).n < PyIntObject(other).n:
    return pyTrueObj
  else:
    return pyFalseObj


proc genPyIntType: PyTypeObject = 
  result = new PyTypeObject
  result.methods.add = addPyInt
  result.methods.substract = substractPyInt
  result.methods.power = powerPyInt
  result.methods.bool = boolPyInt
  result.methods.lt = ltPyInt


let pyIntType = genPyIntType()


proc newPyInt: PyIntObject = 
  result = new PyIntObject
  result.pyType = pyIntType

proc newPyInt*(n: BigInt): PyIntObject = 
  result = newPyInt()
  result.n = n

proc newPyInt*(str: string): PyIntObject = 
  result = newPyInt()
  result.n = str.initBigInt


when isMainModule:
  let n = newPyInt("6666666666666666666")
  echo n

