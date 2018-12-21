import ../Objects/[pyobject, exceptions]

proc builtinPrint*(args: seq[PyObject]): (PyObject, PyExceptionObject) = 
  for obj in args:
    echo obj

