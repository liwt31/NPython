import Objects/pyobject
import Objects/exceptions
#import Objects/methodobject

proc builtinPrint*(args: seq[PyObject]): (PyObject, PyExceptionObject) = 
  for obj in args:
    echo obj

