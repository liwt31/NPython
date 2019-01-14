import strutils
import strformat

import pyobject
import baseBundle
import iterobject
import sliceobject


declarePyType Tuple(reprLock, tpToken):
  items: seq[PyObject]


proc newPyTuple*(items: seq[PyObject]): PyTupleObject = 
  result = newPyTupleSimple()
  # shallow copy
  result.items = items


implTupleMagic eq:
  if not other.ofPyTupleObject:
    return pyFalseObj
  let tOther = PyTupleObject(other)
  if self.items.len != tOther.items.len:
    return pyFalseObj
  for i in 0..<self.items.len:
    let i1 = self.items[i]
    let i2 = tOther.items[i]
    let retObj = i1.callMagic(eq, i2)
    if retObj.isThrownException:
      return retObj
    assert retObj.ofPyBoolObject
    if not PyBoolObject(retObj).b:
      return pyFalseObj
  pyTrueObj


implTupleMagic iter: 
  newPySeqIter(self.items)


implTupleMagic repr:
  var ss: seq[string]
  for item in self.items:
    var itemRepr: PyStrObject
    let retObj = item.callMagic(repr)
    errorIfNotString(retObj, "__repr__")
    itemRepr = PyStrObject(retObj)
    ss.add(itemRepr.str)
  return newPyString("(" & ss.join(", ") & ")")


implTupleMagic str:
  self.reprPyTupleObject


implTupleMagic len:
  newPyInt(self.items.len)

implTupleMagic hash:
  var h = self.id
  for item in self.items:
    h = h xor item.id
  return newPyInt(h)


implTupleMagic getitem:
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


proc newTuple(theType: PyObject, args:seq[PyObject]): PyObject {. cdecl .} = 
  # todo: use macro, add iterable to checkArgTypes
  case args.len:
  of 0:
    result = newPyTupleSimple()
  of 1:
    let iterable = getIterableWithCheck(args[0])
    if iterable.isThrownException:
      return iterable
    let nextMethod = iterable.getMagic(iternext)
    let newTuple = newPyTupleSimple()
    while true:
      let nextObj = nextMethod(iterable)
      if nextObj.isStopIter:
        break
      if nextObj.isThrownException:
        return nextObj
      newTuple.items.add nextObj
    result = newTuple
  else:
    let msg = fmt"tuple expected at most 1 args, got {args.len}"
    return newTypeError(msg)

pyTupleObjectType.magicMethods.new = newTuple

