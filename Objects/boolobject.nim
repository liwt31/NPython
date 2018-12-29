import pyobject

type
  PyBoolObject* = ref object of PyObject
    b*: bool


let pyBoolObjectType* = newPyType("bool")


proc newPyBool(b: bool): PyBoolObject = 
  result = new PyBoolObject
  result.pyType = pyBoolObjectType
  result.b = b


let pyTrueObj* = newPyBool(true)
let pyFalseObj* = newPyBool(false)


proc isPyBoolType*(obj: PyObject): bool = 
  return obj of PyBoolObject
