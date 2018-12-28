import macros except name
import sequtils
import strformat
import strutils

import pyobject
import boolobject
import numobjects
import stringobject
import ../Utils/utils


type
  PyListObject* = ref object of PyObject
    items: seq[PyObject]


proc newPyList*: PyListObject


macro implListUnary(methodName, code:untyped): untyped = 
  result = impleUnary(methodName, ident("PyListObject"), code)


macro implListMethod(methodName, argTypes, code:untyped): untyped = 
  result = impleMethod(methodName, ident("PyListObject"), argTypes, code)


let pyListObjectType = newPyType("list")


implListUnary str:
  var ss: seq[string]
  for item in self.items:
    let itemRepr = item.callMagic(repr)
    errorIfNotString(itemRepr, "__str__")
    if itemRepr of PyStringObject:
      ss.add(PyStringObject(itemRepr).str)
    else:
      let msg = fmt"__str__ returned non-string (type {self.pyType.name})"
      return newTypeError(msg)
  return newPyString("[" & ss.join(", ") & "]")

implListUnary repr:
  strPyListObject(self)


implListMethod append, (item: PyObject):
  self.items.add(args[0])
  pyNone


implListMethod clear, ():
  self.items.setLen 0
  pyNone


implListMethod copy, ():
  let newL = newPyList()
  newL.items = self.items # shallow copy
  result = newL

implListMethod count, ():
  newPyInt(self.items.len)

implListMethod aInt, (i: PyIntObject):
  self.items.add(args[0])
  pyNone


# implListMethod extend:
# require iterators

implListMethod index, (target: PyObject):
  for idx, item in self.items:
    let retObj =  item.callMagic(eq, args[0])
    if retObj.isThrownException:
      return retObj
    if retObj == pyTrueObj:
      return newPyInt(idx)
  return newPyInt(-1)


proc newPyList: PyListObject = 
  new result
  result.pyType = pyListObjectType
