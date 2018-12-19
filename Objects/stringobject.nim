import pyobject


type
  PyStringObj* = ref object of PyObject
    str: string

proc newPyString*(str: string): PyStringObj = 
  result = new PyStringObj
  result.str = str

# used in compile for symbol table
# current we don't have hash so expose
# the interface for convenience
proc nimString*(strObj: PyStringObj): string = 
  strObj.str


method `$`(strObj: PyStringObj): string = 
  "\"" & $strObj.str & "\""
