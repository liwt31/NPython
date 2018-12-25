import hashes

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


macro impleStringUnary(methodName, code:untyped): untyped = 
  result = impleUnary(methodName, ident("PyStringObject"), code)


macro impleStringBinary(methodName, code:untyped): untyped = 
  result = impleBinary(methodName, ident("PyStringObject"), code)

impleStringUnary str:
  self


impleStringUnary repr:
  newPyString($self)


proc newPyString*(str: string): PyStringObject =
  result = new PyStringObject
  result.pyType = pyStringObjectType
  result.str = str

when isMainModule:
  import dictobject
  let d = newPyDict()
  d[newPyString("kkk")] = newPyString("jjj")
  echo d.hasKey(newPyString("kkk"))
  import tables

  var t = initTable[PyStringObject, int]()
  t[newPyString("kkk")] = 0
  echo t.hasKey(newPyString("kkk"))
