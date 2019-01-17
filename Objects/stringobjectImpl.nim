import hashes

import pyobject
import baseBundle
import stringobject

export stringobject

proc hash*(self: PyStrObject): Hash {. inline, cdecl .} = 
  hash(self.str)


proc `==`*(self, other: PyStrObject): bool {. inline, cdecl .} = 
  self.str == other.str


# redeclare this for these are "private" macros

methodMacroTmpl(Str)


implStrMagic eq:
  if not other.ofPyStrObject:
    return pyFalseObj
  if self.str == PyStrObject(other).str:
    return pyTrueObj
  else:
    return pyFalseObj


implStrMagic str:
  self


implStrMagic repr:
  newPyString($self)


implStrMagic hash:
  newPyInt(self.hash)


implStrMagic New(tp: PyObject, obj: PyObject):
  obj.callMagic(str)
