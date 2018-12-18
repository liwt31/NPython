type 
  PyObject* = ref object of RootObj

  PyNone = ref object of PyObject

method `$`*(obj: PyObject): string {.base.} = 
  "Python object"

let pyNone* = new PyNone

