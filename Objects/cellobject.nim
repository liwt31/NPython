import pyobject


declarePyType Cell(tpToken):
  refObj: PyObject # might be nil

proc newPyCell*(content: PyObject): PyCellObject = 
  result = newPyCellSimple()
  result.refObj = content
