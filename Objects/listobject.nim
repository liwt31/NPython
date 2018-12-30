import macros except name
import sequtils
import strformat
import strutils

import bigints

import pyobject
import boolobject
import numobjects
import stringobject
import iterobject
import ../Utils/utils

declarePyType List():
  items: seq[PyObject]

proc newPyList*: PyListObject

implListUnary repr:
  var ss: seq[string]
  for item in self.items:
    var itemRepr: PyStrObject
    if item.reprEnter:
      let retObj = item.callMagic(repr)
      item.reprLeave
      errorIfNotString(retObj, "__repr__")
      itemRepr = PyStrObject(retObj)
    else:
      itemRepr = newPyString("[...]")
    ss.add(itemRepr.str)
  return newPyString("[" & ss.join(", ") & "]")


implListUnary len:
  return newPyInt(self.items.len)


implListMethod *append, (item: PyObject):
  self.items.add(item)
  pyNone


implListMethod *clear:
  self.items.setLen 0
  pyNone


implListMethod copy:
  let newL = newPyList()
  newL.items = self.items # shallow copy
  result = newL


implListMethod count, (target: PyObject):
  var count: int
  for item in self.items:
    let retObj = item.callMagic(eq, target)
    if retObj.isThrownException:
      return retObj
    if retObj == pyTrueObj:
      inc count
  newPyInt(count)

# for lock testing
#[
implListMethod doClear, ():
  self.clearPyListObject()

implListMethod *doRead, ():
  return self.doClearPyListObject()

]#

# for checkArgTypes testing
#[
implListMethod aInt, (i: PyIntObject):
  self.items.add(i)
  pyNone

]#

# implListMethod extend:
# require iterators

implListMethod index, (target: PyObject):
  for idx, item in self.items:
    let retObj =  item.callMagic(eq, target)
    if retObj.isThrownException:
      return retObj
    if retObj == pyTrueObj:
      return newPyInt(idx)
  newValueError(fmt"{target} is not in list")


implListMethod *insert, (idx: PyIntObject, item: PyObject):
  var intIdx: int
  if 0 < idx.v:
    intIdx = 0
  # len is of type `int` while the bigint lib only support comparison with `int32`
  # fix this while dealing with the many problems with bigint lib
  elif self.items.len.initBigInt < idx.v:
    intIdx = self.items.len
  else:
    intIdx = idx.toInt
  self.items.insert(item, intIdx)
  pyNone


implListMethod *pop:
  if self.items.len == 0:
    return newIndexError("pop from empty list")
  self.items.pop

implListMethod *remove, (target: PyObject):
  let retObj = indexPyListObject(selfNoCast, @[target])
  if retObj.isThrownException:
    return retObj
  assert retObj of PyIntObject
  let idx = PyIntObject(retObj).toInt
  self.items.delete(idx, idx+1)


proc iter(selfNoCast: PyObject): PyObject = 
  let self = PyListObject(selfNoCast)
  newPySeqIter(self.items)

pyListObjectType.iter = iter

proc newPyList: PyListObject = 
  new result
  result.pyType = pyListObjectType
