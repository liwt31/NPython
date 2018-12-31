import typetraits
import strformat
import tables

import pyobject
import dictobject
import boolobjectImpl
import stringobject
import methodobject
import descrobject

import ../Utils/utils


methodMacroTmpl(Type, "Type")


let pyTypeObjectType = newPyType("type")


implTypeUnary repr:
  newPyString(self.name)

implTypeUnary str:
  self.reprPyTypeObject


proc getTypeDict*(obj: PyObject): PyDictObject = 
  PyDictObject(obj.pyType.dict)


proc hasDict*(obj: PyObject): bool {. inline .} = 
  0 < obj.pyType.dictOffset


proc getDict*(obj: PyObject): PyDictObject = 
  let tp = obj.pyType
  if tp.dictOffset < 0:
    unreachable("obj has no dict. Use hasDict before get dict")
  let dictPtr = cast[ptr PyDictObject](cast[int](obj[].addr) + tp.dictOffset)
  dictPtr[]

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

  "__len__",
  "__str__",
  "__repr__",
  "__getattribute__",
]


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


# generic getattr
proc getAttr(self: PyObject, nameObj: PyObject): PyObject = 
  if not nameObj.isPyStringType:
    let typeStr = nameObj.pyType.name
    return newTypeError(fmt"attribute name must be string, not {typeStr}")
  let name = PyStrObject(nameObj)
  let typeDict = self.getTypeDict
  if typeDict == nil:
    unreachable("for type object d must not be nil")
  if typeDict.hasKey(name):
    let descr = typeDict[name]
    if descr.pyType.descrGet == nil:
      return descr
    else:
      let getFun = descr.pyType.descrGet
      return descr.getFun(self)

  # todo: check dict of current obj
  if self.hasDict:
    let instDict = self.getDict
    if instDict.hasKey(name):
      return instDict[name]
  # a hasDict attribute in type object
  return newAttributeError($self.pyType.name, $name)
  

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
  if m.str == nil:
    t.magicMethods.str = m.repr


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
