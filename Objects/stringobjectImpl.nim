import stringobject
import pyobject
import hashes
import boolobject
import numobjects

export stringobject

proc hash*(self: PyStrObject): Hash {. inline, cdecl .} = 
  hash(self.str)


proc `==`*(self, other: PyStrObject): bool {. inline, cdecl .} = 
  self.str == other.str


# redeclare this for these are "private" macros

methodMacroTmpl(Str, "str")


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
