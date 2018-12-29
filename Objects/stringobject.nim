import hashes
import macros

import pyobject


type
  PyStringObject* = ref object of PyObject
    str*: string

proc newPyString*(str: string): PyStringObject

method `$`*(strObj: PyStringObject): string =
  "\"" & $strObj.str & "\""


method hash*(obj: PyStringObject): Hash =
  return hash(obj.str)

# have to define this to override the PyObject default
method `==`*(str1, str2: PyStringObject): bool =
  return str1.str == str2.str


let pyStringObjectType = newPyType("str")


macro implStringUnary(methodName, code:untyped): untyped = 
  implUnary(methodName, ident("PyStringObject"), code)


macro implStringBinary(methodName, code:untyped): untyped = 
  implBinary(methodName, ident("PyStringObject"), code)

implStringUnary str:
  self


implStringUnary repr:
  newPyString($self)


proc newPyString*(str: string): PyStringObject =
  result = new PyStringObject
  result.pyType = pyStringObjectType
  result.str = str


proc isPyStringType*(obj: PyObject): bool = 
  # currently just check exact string
  # include inherit in the future
  obj of PyStringObject


when isMainModule:
  import dictobject
  let d = newPyDict()
  d[newPyString("kkk")] = newPyString("jjj")
  echo d.hasKey(newPyString("kkk"))
  import tables

  var t = initTable[PyStringObject, int]()
  t[newPyString("kkk")] = 0
  echo t.hasKey(newPyString("kkk"))
