import pyobject

declarePyType Bool(tpToken):
  b: bool

proc newPyBool(b: bool): PyBoolObject = 
  result = newPyBoolSimple()
  result.b = b


let pyTrueObj* = newPyBool(true)
let pyFalseObj* = newPyBool(false)
