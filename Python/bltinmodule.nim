import ../Objects/[pyobject, stringobject, exceptions]

proc builtinPrint*(args: seq[PyObject]): PyObject =
  for obj in args:
    let objStr = obj.call(str)
    if objStr of PyStringObject:
      echo PyStringObject(objStr).str
    else:
      return newTypeError("__str__ returned non-string (type {objStr.pyType.name})")
  pyNone

