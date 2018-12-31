import pyobject
import stringobject


declarePyType Module(dict):
  name: PyStrObject



proc newPyModule*(name: PyStrObject): PyModuleObject = 
  new result
  result.pyType = pyModuleObjectType
  result.name = name

