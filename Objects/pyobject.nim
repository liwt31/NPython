type 
  PyObject* = ref object of RootObj

  PyNone = ref object of PyObject

method `$`*(obj: PyObject): string {.base.} = 
  "Python object"

method `$`*(obj: PyNone): string =
  "None"

let pyNone* = new PyNone

