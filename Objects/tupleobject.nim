import strutils

import pyobject
import baseBundle
import iterobject
import sliceobject


declarePyType Tuple(reprLock):
  items: seq[PyObject]


proc newPyTuple*(items: seq[PyObject]): PyTupleObject = 
  result = newPyTupleSimple()
  # shallow copy
  result.items = items


implTupleUnary iter: 
  newPySeqIter(self.items)


implTupleUnary repr:
  var ss: seq[string]
  for item in self.items:
    var itemRepr: PyStrObject
    let retObj = item.callMagic(repr)
    errorIfNotString(retObj, "__repr__")
    itemRepr = PyStrObject(retObj)
    ss.add(itemRepr.str)
  return newPyString("(" & ss.join(", ") & ")")


implTupleUnary str:
  self.reprPyTupleObject


implTupleUnary len:
  newPyInt(self.items.len)

implTupleUnary hash:
  var h = self.id
  for item in self.items:
    h = h xor item.id
  return newPyInt(h)


implTupleBinary getitem:
  if other.ofPyIntObject:
    let idx = getIndex(PyIntObject(other), self.items.len)
    return self.items[idx]
  if other.ofPySliceObject:
    let slice = PySliceObject(other)
    let newList = newPyTupleSimple()
    let retObj = slice.getSliceItems(self.items.addr, newList.items.addr)
    if retObj.isThrownException:
      return retObj
    else:
      return newList
    
  return newIndexTypeError("tuple", other)


