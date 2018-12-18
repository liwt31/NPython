import tables

import bigints

import pyobject


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

proc newPyInt*(str: string): PyIntObject = 
  result = new PyIntObject
  result.n = str.initBigInt


when isMainModule:
  let n = newPyInt("6666666666666666666")
  echo n

