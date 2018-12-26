import ../Objects/[pyobject, typeobject, dictobject, stringobject, listobject]
import ../Utils/utils


proc builtinPrint*(args: seq[PyObject]): PyObject =
  for obj in args:
    let objStr = obj.callMagic(str)
    errorIfNotString(objStr, "__str__")
    echo PyStringObject(objStr).str
  pyNone


proc builtinList*(elms: seq[PyObject]): PyObject = 
  result = newPyList()
  for elm in elms:
    let retObj = result.callBltin("append", elm)
    if retObj.isThrownException:
      return retObj

# this should be moved to python level
proc builtinDir*(args: seq[PyObject]): PyObject = 
  if args.len != 1:
    return newTypeError("dir expected 1 arguments, got {args.len}")
  args[0].pyType.getDict.keys



