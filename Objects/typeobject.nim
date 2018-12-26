import typetraits
import tables

import pyobject
import dictobject
import stringobject
import methodobject

proc getDict*(tp: PyTypeObject): PyDictObject = 
  PyDictObject(tp.dict)

const magicNames = [
  "__add__",
  "__sub__",
  "__mul__",
  "__truediv__",
  "__floordiv__",
  "__mod__",
  "__pow__",

  "__not__",
  "__negative__",
  "__positive__",
  "__abs__",
  "__bool__",

  "__and__",
  "__xor__",
  "__or__",

  "__lt__",
  "__le__",
  "__eq__",
  "__ne__",
  "__gt__",
  "__ge__",

  "__str__",
  "__repr__",
]

let pyTypeObjectType = newPyType("type")

static:
  assert type(PyTypeObject.magicMethods).arity == magicNames.len

proc typeReady*(t: PyTypeObject) = 
  let d = newPyDict()
  # magic methods. field loop syntax is pretty weird
  var i = 0
  for meth in t.magicMethods.fields:
    if meth != nil:
      let name = newPyString(magicNames[i])
      d[name] = newPyWrapperObject(meth)
      inc i
   
  for name, fun in t.bltinMethods.pairs:
    let namePyStr = newPyString(name)
    d[namePyStr] = newPyWrapperObject(fun)

  t.dict = d


