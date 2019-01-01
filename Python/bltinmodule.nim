import ../Objects/[pyobject, typeobject, dictobject, 
                   stringobject, listobject, moduleobject]
import ../Utils/utils

# can well use some macros for argument checking

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

proc builtinDir*(args: seq[PyObject]): PyObject = 
  # why in CPython 0 argument becomes `locals()`? no idea
  if args.len != 1:
    return newTypeError("dir expected 1 arguments, got {args.len}")
  let obj = args[0]
  # get mapping proxy first then talk about how do deal with __dict__ of type
  var mergedDict = newPyDict()
  mergedDict.update(obj.getTypeDict)
  if obj.hasDict:
    mergedDict.update(obj.getDict)
  mergedDict.keys


proc builtinType*(args: seq[PyObject]): PyObject = 
  if args.len != 1:
    return newTypeError("type expected 1 arguments, got {args.len}")
  let obj = args[0]
  obj.pyType

