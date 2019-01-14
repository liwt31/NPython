import pyobject
import boolobject

declarePyType None(tpToken):
  discard

let pyNone* = newPyNoneSimple()

implNoneMagic eq:
  if other.ofPyNoneObject:
    return pyTrueObj
  else:
    return pyFalseObj
