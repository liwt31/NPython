import pyobject


type
  PyBoolObject = ref object of PyObject

  PyTrueObject = ref object of PyBoolObject

  PyFalseObject = ref object of PyBoolObject

let pyTrueObj* = new PyTrueObject
let pyFalseObj* = new PyFalseObject


method `$`*(obj: PyTrueObject): string = 
  "True"

method `$`*(obj: PyFalseObject): string = 
  "False"

