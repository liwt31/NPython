import macros

import pyobject


declarePyType Str(tpToken):
  str: string

method `$`*(strObj: PyStrObject): string =
  "\"" & $strObj.str & "\""

proc newPyString*(str: string): PyStrObject =
  result = newPyStrSimple()
  result.str = str

let newPyStr* = newPyString
