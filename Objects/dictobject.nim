import strformat
import hashes
import strutils
import tables
import macros

import pyobject 
import listobject
import baseBundle
import ../Utils/utils


# hash functions for py objects
# raises an exception to indicate type error. Should fix this
# when implementing custom dict
proc hash*(obj: PyObject): Hash {. inline, cdecl .} = 
  let fun = obj.pyType.magicMethods.hash
  if fun.isNil:
    return hash(addr(obj[]))
  else:
    let retObj = fun(obj)
    if not retObj.ofPyIntObject:
      raise newException(DictError, retObj.pyType.name)
    return hash(cast[PyIntObject](retObj).v)


proc `==`*(obj1, obj2: PyObject): bool {. inline, cdecl .} =
  let fun = obj1.pyType.magicMethods.eq
  if fun.isNil:
    return obj1.id == obj2.id
  else:
    let retObj = fun(obj1, obj2)
    if not retObj.ofPyBoolObject:
      raise newException(DictError, retObj.pyType.name)
    return cast[PyBoolObject](retObj).b


# currently not ordered
# nim ordered table has O(n) delete time
# todo: implement an ordered dict 
declarePyType dict(reprLock, mutable):
  table: Table[PyObject, PyObject]


proc newPyDict* : PyDictObject = 
  result = newPyDictSimple()
  result.table = initTable[PyObject, PyObject]()

proc hasKey*(dict: PyDictObject, key: PyObject): bool = 
  return dict.table.hasKey(key)

proc `[]`*(dict: PyDictObject, key: PyObject): PyObject = 
  return dict.table[key]


proc `[]=`*(dict: PyDictObject, key, value: PyObject) = 
  dict.table[key] = value


implDictUnary repr:
  var ss: seq[string]
  for k, v in self.table.pairs:
    let kRepr = k.callMagic(repr)
    let vRepr = v.callMagic(repr)
    errorIfNotString(kRepr, "__str__")
    errorIfNotString(vRepr, "__str__")
    ss.add fmt"{PyStrObject(kRepr).str}: {PyStrObject(vRepr).str}"
  return newPyString("{" & ss.join(", ") & "}")


implDictUnary len:
  newPyInt(self.table.len)


implDictUnary str:
  reprPyDictObject(self)
  

proc newPyDictObject(self: PyObject, args: seq[PyObject]): PyObject {. cdecl .} =
  newPyDict()
pyDictObjectType.magicMethods.new = newPyDictObject
  

template checkHashableTmpl(obj) = 
  let hashFunc = obj.pyType.magicMethods.hash
  if hashFunc.isNil:
    let tpName = obj.pyType.name
    return newTypeError(fmt"unhashable type: " & tpName)


implDictBinary getitem:
  checkHashableTmpl(other)
  try:
    result = self.table.getOrDefault(other, nil)
  except DictError:
    return newTypeError("__hash__ method doesn't return an integer or __eq__ method doesn't return a bool")
  if not (result.isNil):
    return result

  var msg: string
  let repr = other.pyType.magicMethods.repr(other)
  if repr.isThrownException:
    msg = "exception occured when generating key error msg calling repr"
  elif not repr.ofPyStrObject:
    msg = "repr returned non-string when generating key error msg"
  else:
    msg = PyStrObject(repr).str
  return newKeyError(msg)

implDictTernary setitem:
  checkHashableTmpl(arg1)
  try:
    self.table[arg1] = arg2
  except DictError:
    return newTypeError("__hash__ method doesn't return an integer or __eq__ method doesn't return a bool")
  pyNone

# in real python this would return a iterator
# this function is used internally
proc keys*(d: PyDictObject): PyListObject = 
  result = newPyList()
  for key in d.table.keys:
    let rebObj = result.appendPyListObject(@[key])
    if rebObj.isThrownException:
      unreachable("No chance for append to thrown exception")


proc update*(d1, d2: PyDictObject) = 
  for k, v in d2.table.pairs:
    d1[k] = v

when isMainModule:
  let s1 = newPyString("1")
  let s2 = newPyString("1")
  let d = newPyDict()
  d[s1] = newPyString("kk")
  echo d.hasKey(s2)
