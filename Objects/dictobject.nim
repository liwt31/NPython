import strformat
import strutils
import tables
import macros


import pyobject 
import listobject
import stringobject
import ../Utils/utils

type 
  PyDictObject* = ref object of PyObject
    # nim ordered table has O(n) delete time
    # todo: implement an ordered dict 
    table: Table[PyObject, PyObject]



proc hasKey*(dict: PyDictObject, key: PyObject): bool = 
  return dict.table.hasKey(key)

proc `[]`*(dict: PyDictObject, key: PyObject): PyObject = 
  return dict.table[key]


proc `[]=`*(dict: PyDictObject, key, value: PyObject) = 
  dict.table[key] = value

let pyDictObjectType = newPyType("dict")


macro implDictUnary(methodName, code:untyped): untyped = 
  result = implUnary(methodName, ident("PyDictObject"), code)


macro implDictMethod(methodName, argTypes, code:untyped): untyped = 
  result = implMethod(methodName, ident("PyDictObject"), argTypes, code)


#[
proc combine*(dict1: PyDictObject, dict2: PyDictObject): PyDictObject = 
  result = newPyDict()
  for k, v in dict1.table.pairs:
    result[k] = v
  for k, v in dict2.table.pairs:
    if result.hasKey(k):
      assert false
    result[k] = v
]#


implDictUnary str:
  var ss: seq[string]
  for k, v in self.table.pairs:
    let kRepr = k.callMagic(repr)
    let vRepr = v.callMagic(repr)
    errorIfNotString(kRepr, "__str__")
    errorIfNotString(vRepr, "__str__")
    ss.add fmt"{kRepr}: {vRepr}"
  return newPyString("{" & ss.join(", ") & "}")
  

implDictUnary repr:
  strPyDictObject(self)

# in real python this would return a iteration
# this function is used internally
proc keys*(d: PyDictObject): PyListObject = 
  result = newPyList()
  for key in d.table.keys:
    let rebObj = result.appendPyListObject(@[key])
    if rebObj.isThrownException:
      unreachable("No chance for append to thrown exception")



proc update*(d1, d2: PyDictObject) = 
  for k, v in d2.table.pairs:
    d1[k] = v


proc newPyDict* : PyDictObject = 
  new result
  result.table = initTable[PyObject, PyObject]()
  result.pyType = pyDictObjectType
