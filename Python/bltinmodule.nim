import ../Objects/[pyobject, typeobject, dictobject, stringobject, listobject]
import ../Utils/utils


proc builtinPrint*(args: seq[PyObject]): PyObject =
  for obj in args:
    let objStr = obj.callMagic(str)
    errorIfNotString(objStr, "__str__")
    echo PyStrObject(objStr).str
  pyNone


proc builtinList*(elms: seq[PyObject]): PyObject = 
  result = newPyList()
  for elm in elms:
    let retObj = result.appendPyListObject(@[elm])
    if retObj.isThrownException:
      return retObj

# this should be moved to python level
proc builtinDir*(args: seq[PyObject]): PyObject = 
  # why in CPython 0 argument becomes `locals()`? no idea
  if args.len != 1:
    return newTypeError("dir expected 1 arguments, got {args.len}")
  let obj = args[0]
  # get mapping proxy first then talk about how do deal with __dict__ of type
  obj.pyType.getDict.keys



