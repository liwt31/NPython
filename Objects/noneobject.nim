import pyobject
import boolobject

declarePyType None(tpToken):
  discard

let pyNone* = newPyNoneSimple()

implNoneBinary eq:
  if other.ofPyNoneObject:
    return pyTrueObj
  else:
    return pyFalseObj
