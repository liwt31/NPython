import macros
import strformat
import strutils

import pyobject
import stringobject
import exceptions
import ../Utils/utils


type
  PyListObject = ref object of PyObject
    items: seq[PyObject]


proc newPyList*: PyListObject


macro impleListUnary(methodName, code:untyped): untyped = 
  result = impleUnary(methodName, ident("PyListObject"), code)


macro impleListMethod(methodName, code:untyped): untyped = 
  result = impleMethod(methodName, ident("PyListObject"), code)


let pyListObjectType = newPyType("list")


impleListUnary str:
  var ss: seq[string]
  for item in self.items:
    let itemRepr = item.callMagic(repr)
    if itemRepr of PyStringObject:
      ss.add(PyStringObject(itemRepr).str)
    else:
      let msg = fmt"__str__ returned non-string (type {self.pyType.name})"
      return newTypeError(msg)
  return newPyString("[" & ss.join(", ") & "]")

impleListUnary repr:
  strPyListObject(self)


impleListMethod append:
  if 2 < args.len:
    return newTypeError(fmt"append() takes exactly one argument ({args.len - 1} given)")
  self.items.add(args[1])


proc newPyList: PyListObject = 
  new result
  result.pyType = pyListObjectType
