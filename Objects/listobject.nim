import macros
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


macro implListMethod(methodName, code:untyped): untyped = 
  result = impleMethod(methodName, ident("PyListObject"), code)


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


implListMethod append:
  checkArgNum(1, "append")
  self.items.add(args[0])
  pyNone


implListMethod clear:
  checkArgNum(0, "clear")
  self.items.setLen 0
  pyNone


implListMethod copy:
  checkArgNum(0, "copy")
  let newL = newPyList()
  newL.items = self.items # shallow copy
  result = newL

implListMethod count:
  checkArgNum(0, "count")
  newPyInt(self.items.len)


# implListMethod extend:
# require iterators

implListMethod index:
  checkArgNum(1, "index")
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
