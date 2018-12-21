import pyobject


type
  PyBoolObject = ref object of PyObject
    b: bool

proc boolPyBool(self: PyObject): PyObject = 
  self


proc genPyBoolType: PyTypeObject = 
  result = new PyTypeObject
  result.methods.bool = boolPyBool


let pyBoolType = genPyBoolType()


proc newPyBool(b: bool): PyBoolObject = 
  result = new PyBoolObject
  result.pyType = pyBoolType
  result.b = b

let pyTrueObj* = newPyBool(true)
let pyFalseObj* = newPyBool(false)


method `$`*(obj: PyBoolObject): string = 
  $obj.b
