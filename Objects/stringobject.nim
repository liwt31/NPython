import macros

import pyobject


declarePyType Str():
  str: string

method `$`*(strObj: PyStrObject): string =
  "\"" & $strObj.str & "\""


proc newPyString*(str: string): PyStrObject =
  result = newPyStrSimple()
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
