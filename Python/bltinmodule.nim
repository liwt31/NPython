import ../Objects/[pyobject, exceptions]

proc builtinPrint*(args: seq[PyObject]): PyObject =
  for obj in args:
    echo obj
  pyNone

