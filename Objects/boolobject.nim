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


proc newPyBoolObj(b: bool): PyBoolObject = 
  result = new PyBoolObject
  result.pyType = pyBoolType
  result.b = b

let pyTrueObj* = newPyBoolObj(true)
let pyFalseObj* = newPyBoolObj(false)


method `$`*(obj: PyBoolObject): string = 
  $obj.b
