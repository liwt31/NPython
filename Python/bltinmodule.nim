import ../Objects/[pyobject, stringobject, listobject, exceptions]
import ../Utils/utils

proc builtinPrint*(args: seq[PyObject]): PyObject =
  for obj in args:
    let objStr = obj.callMagic(str)
    if objStr of PyStringObject:
      echo PyStringObject(objStr).str
    else:
      return newTypeError("__str__ returned non-string (type {objStr.pyType.name})")
  pyNone


proc builtinList*(elms: seq[PyObject]): PyObject = 
  result = newPyList()
  for elm in elms:
    let retObj = result.callBltin("append", elm)
    if retObj.isThrownException:
      return retObj


