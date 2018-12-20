import Objects/pyobject
#import Objects/methodobject


proc builtinPrint*(args: seq[PyObject]): PyObject = 
  for obj in args:
    echo obj

