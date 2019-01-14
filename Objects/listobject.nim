import sequtils
import strformat
import strutils

import bigints

import pyobject
import baseBundle
import sliceobject
import iterobject
import ../Utils/utils

declarePyType List(reprLock, mutable, tpToken):
  items: seq[PyObject]


proc newPyList*: PyListObject = 
  newPyListSimple()

proc newPyList*(items: seq[PyObject]): PyListObject = 
  result = newPyList()
  result.items = items


implListMagic contains:
  for idx, item in self.items:
    let retObj =  item.callMagic(eq, other)
    if retObj.isThrownException:
      return retObj
    if retObj == pyTrueObj:
      return pyTrueObj
  return pyFalseObj


implListMagic iter: 
  newPySeqIter(self.items)


implListMagic repr:
  var ss: seq[string]
  for item in self.items:
    var itemRepr: PyStrObject
    let retObj = item.callMagic(repr)
    errorIfNotString(retObj, "__repr__")
    itemRepr = PyStrObject(retObj)
    ss.add(itemRepr.str)
  return newPyString("[" & ss.join(", ") & "]")

implListMagic str:
  self.reprPyListObject

implListMagic len:
  newPyInt(self.items.len)

implListMagic getitem:
  if other.ofPyIntObject:
    let idx = getIndex(PyIntObject(other), self.items.len)
    return self.items[idx]
  if other.ofPySliceObject:
    let slice = PySliceObject(other)
    let newList = newPyList()
    let retObj = slice.getSliceItems(self.items.addr, newList.items.addr)
    if retObj.isThrownException:
      return retObj
    else:
      return newList
    
  return newIndexTypeError("list", other)


implListMagic *setitem:
  if arg1.ofPyIntObject:
    let idx = getIndex(PyIntObject(arg1), self.items.len)
    self.items[idx] = arg2
    return pyNone
  if arg1.ofPySliceObject:
    return newTypeError("store to slice not implemented")
  return newIndexTypeError("list", arg1)


proc append(self: PyListObject, item: PyObject) {. inline .} = 
  self.items.add(item)


implListMethod *append(item: PyObject):
  self.append(item)
  pyNone


implListMethod *clear():
  self.items.setLen 0
  pyNone


implListMethod copy():
  let newL = newPyList()
  newL.items = self.items # shallow copy
  newL


implListMethod count(target: PyObject):
  var count: int
  for item in self.items:
    let retObj = item.callMagic(eq, target)
    if retObj.isThrownException:
      return retObj
    if retObj == pyTrueObj:
      inc count
  newPyInt(count)

# some test methods just for debugging
when not defined(release):
  # for lock testing
  implListMethod doClear():
  # should fail because trying to write while reading
    self.clearPyListObject()

  implListMethod *doRead():
    # trying to read whiel writing
    return self.doClearPyListObject()


  # for checkArgTypes testing
  implListMethod aInt(i: PyIntObject):
    self.items.add(i)
    pyNone

  # for macro pragma testing
  macro hello(code: untyped): untyped = 
    code.body.insert(0, nnkCommand.newTree(ident("echo"), newStrLitNode("hello")))
    code

  implListMethod hello(), [hello]:
    pyNone

# implListMethod extend:
# todo
#

implListMethod index(target: PyObject):
  for idx, item in self.items:
    let retObj =  item.callMagic(eq, target)
    if retObj.isThrownException:
      return retObj
    if retObj == pyTrueObj:
      return newPyInt(idx)
  let msg = fmt"{target} is not in list"
  newValueError(msg)



implListMethod *insert(idx: PyIntObject, item: PyObject):
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


implListMethod *pop():
  if self.items.len == 0:
    let msg = "pop from empty list"
    return newIndexError(msg)
  self.items.pop

implListMethod *remove(target: PyObject):
  let retObj = indexPyListObject(selfNoCast, @[target])
  if retObj.isThrownException:
    return retObj
  assert retObj.ofPyIntObject
  let idx = PyIntObject(retObj).toInt
  self.items.delete(idx, idx+1)


proc newList(theType: PyObject, args:seq[PyObject]): PyObject {. cdecl .} = 
  # todo: use macro, add iterable to checkArgTypes
  case args.len:
  of 0:
    result = newPyListSimple()
  of 1:
    let iterable = getIterableWithCheck(args[0])
    if iterable.isThrownException:
      return iterable
    let nextMethod = iterable.getMagic(iternext)
    let newList = newPyListSimple()
    while true:
      let nextObj = nextMethod(iterable)
      if nextObj.isStopIter:
        break
      if nextObj.isThrownException:
        return nextObj
      newList.items.add nextObj
    result = newList
  else:
    let msg = fmt"list expected at most 1 args, got {args.len}"
    return newTypeError(msg)

pyListObjectType.magicMethods.new = newList

