import hashes
import macros

import pyobject


declarePyType Str():
  str: string

proc newPyString*(str: string): PyStrObject

method `$`*(strObj: PyStrObject): string =
  "\"" & $strObj.str & "\""


method hash*(obj: PyStrObject): Hash =
  return hash(obj.str)

# have to define this to override the PyObject default
method `==`*(str1, str2: PyStrObject): bool =
  return str1.str == str2.str


implStrUnary str:
  self


implStrUnary repr:
  newPyString($self)


proc newPyString*(str: string): PyStrObject =
  result = new PyStrObject
  result.pyType = pyStrObjectType
  result.str = str


proc isPyStringType*(obj: PyObject): bool = 
  # currently just check exact string
  # include inherit in the future
  obj of PyStrObject


when isMainModule:
  import dictobject
  let d = newPyDict()
  d[newPyString("kkk")] = newPyString("jjj")
  echo d.hasKey(newPyString("kkk"))
  import tables

  var t = initTable[PyStrObject, int]()
  t[newPyString("kkk")] = 0
  echo t.hasKey(newPyString("kkk"))
