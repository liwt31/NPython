import typetraits
import strformat
import tables

import pyobject
import exceptions
import dictobject
import boolobjectImpl
import stringobjectImpl
import methodobject
import descrobject

import ../Utils/utils


methodMacroTmpl(Type, "Type")


let pyTypeObjectType = newPyType("type")
setDictOffset(Type)


implTypeUnary repr:
  newPyString(self.name)

implTypeUnary str:
  self.reprPyTypeObject


proc getTypeDict*(obj: PyObject): PyDictObject = 
  PyDictObject(obj.pyType.dict)


proc hasDict*(obj: PyObject): bool {. inline .} = 
  0 < obj.pyType.dictOffset


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

  "__new__",
  "__init__",
  "__getattribute__",
  "__hash__",
  "__dict__",
  "__call__",

  "__getitem__",
  "__setitem__",

  "__get__",

  "__iter__",
  "__next__",
]


static:
  assert type(PyTypeObject.magicMethods).arity == magicNames.len

# some generic behaviors that every type should obey
proc le(o1, o2: PyObject): PyObject {. cdecl .} =
  let lt = o1.callMagic(lt, o2)
  let eq = o1.callMagic(eq, o2)
  lt.callMagic(Or, eq)

proc ne(o1, o2: PyObject): PyObject {. cdecl .} =
  let eq = o1.callMagic(eq, o2)
  eq.callMagic(Not)

proc ge(o1, o2: PyObject): PyObject {. cdecl .} = 
  let gt = o1.callMagic(gt, o2)
  let eq = o1.callMagic(eq, o2)
  gt.callMagic(Or, eq)

proc reprDefault(self: PyObject): PyObject {. cdecl .} = 
  newPyString(fmt"<{self.pyType.name} at {self.idStr}>")


proc strDefault(self: PyObject): PyObject {. cdecl .} = 
  self.reprDefault


# generic getattr
proc getAttr(self: PyObject, nameObj: PyObject): PyObject {. cdecl .} = 
  if not nameObj.ofPyStrObject:
    let typeStr = nameObj.pyType.name
    return newTypeError(fmt"attribute name must be string, not {typeStr}")
  let name = PyStrObject(nameObj)
  let typeDict = self.getTypeDict
  if typeDict == nil:
    unreachable("for type object d must not be nil")
  if typeDict.hasKey(name):
    let descr = typeDict[name]
    let descrGet = descr.pyType.magicMethods.get
    if descrGet == nil:
      return descr
    else:
      return descr.descrGet(self)

  if self.hasDict:
    let instDict = PyDictObject(self.getDict)
    if instDict.hasKey(name):
      return instDict[name]
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
    t.magicMethods.str = strDefault
  if m.repr == nil:
    t.magicMethods.repr = reprDefault


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

proc newInstance*(selfNoCast: PyObject, args: seq[PyObject]): 
  PyObject {. castSelf: PyTypeObject, cdecl .} = 
  let newFunc = self.magicMethods.new
  if newFunc == nil:
    return newTypeError(fmt"cannot create '{self.name}' instances because __new__ is not set")
  let newObj = self.newFunc(args)
  if newObj.isThrownException:
    return newObj
  let initFunc = self.magicMethods.init
  if initFunc != nil:
    let initRet = self.initFunc(args)
    if initRet.isThrownException:
      return initRet
  return newObj

pyTypeObjectType.magicMethods.call = newInstance
