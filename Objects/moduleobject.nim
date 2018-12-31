import pyobject
import stringobject


declarePyType Module(dict):
  name: PyStrObject


proc newPyModule*(name: PyStrObject): PyModuleObject = 
  result = newPyModuleSimple()
  result.pyType = pyModuleObjectType
  result.name = name

