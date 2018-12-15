type PyObject* = ref object of RootObj

method `$`*(obj: PyObject): string {.base.} = 
  "Python object"
