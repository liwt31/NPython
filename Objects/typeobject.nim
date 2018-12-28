import typetraits
import strformat
import tables

import pyobject
import dictobject
import boolobject
import stringobject
import methodobject
import descrobject

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
  "__getattribute__",
]

let pyTypeObjectType = newPyType("type")

static:
  assert type(PyTypeObject.magicMethods).arity == magicNames.len

# some generic behaviors that every type should obey
proc le(o1, o2: PyObject): PyObject =
  let lt = o1.callMagic(lt, o2)
  let eq = o1.callMagic(eq, o2)
  lt.callMagic(Or, eq)

proc ne(o1, o2: PyObject): PyObject =
  let eq = o1.callMagic(eq, o2)
  eq.callMagic(Not)

proc ge(o1, o2: PyObject): PyObject = 
  let gt = o1.callMagic(gt, o2)
  let eq = o1.callMagic(eq, o2)
  gt.callMagic(Or, eq)

proc str(self: PyObject): PyObject = 
  newPyString(fmt"<{self.pyType.name} at {self.idStr}>")

proc repr(self: PyObject): PyObject = 
  self.str


proc getAttr(self: PyObject, nameObj: PyObject): PyObject = 
  if not nameObj.isPyStringType:
    let typeStr = nameObj.pyType.name
    return newTypeError(fmt"attribute name must be string, not {typeStr}")
  let name = PyStringObject(nameObj)
  let d = self.pyType.getDict
  # todo, check if d is null and return exception
  if not (d.hasKey(name)):
    return newAttributeError($self.pyType.name, $name)
  let descr = d[name]
  if descr.pyType.descrGet == nil:
    return descr
  else:
    let getFun = descr.pyType.descrGet
    return descr.getFun(self)
  

proc addGeneric(t: PyTypeObject) = 
  # a shortcut for read, can not assign
  let m = t.magicMethods
  if m.lt != nil and m.eq != nil and m.le == nil:
    t.magicMethods.le = le
  if m.eq != nil and m.ne == nil:
    t.magicMethods.ne = ne
  if m.ge != nil and m.eq != nil and m.ge == nil:
    t.magicMethods.ge = ge
  t.magicMethods.getattr = getAttr
  if m.str == nil:
    t.magicMethods.str = str
  if m.repr == nil:
    t.magicMethods.repr = repr


proc typeReady*(t: PyTypeObject) = 
  t.pyType = pyTypeObjectType
  t.addGeneric

  let d = newPyDict()
  # magic methods. field loop syntax is pretty weird
  var i = 0
  for meth in t.magicMethods.fields:
    if meth != nil:
      let namePyStr = newPyString(magicNames[i])
      d[namePyStr] = t.newPyMethodDescr(meth, namePyStr)
    inc i
   
  for name, meth in t.bltinMethods.pairs:
    let namePyStr = newPyString(name)
    d[namePyStr] = t.newPyMethodDescr(meth, namePyStr)

  t.dict = d

pyTypeObjectType.typeReady()
