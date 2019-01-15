import typetraits
import strformat
import strutils
import tables

import pyobject
import exceptionsImpl
import dictobject
import tupleobject
import boolobjectImpl
import stringobjectImpl
import methodobject
import funcobject
import descrobject

import ../Utils/utils

# PyTypeObject is manually declared in pyobjectBase.nim
# here we need to do some initialization
methodMacroTmpl(Type, "Type")


let pyTypeObjectType* = newPyType("type")
setDictOffset(Type)
pyTypeObjectType.tp = PyTypeToken.Type


implTypeMagic repr:
  newPyString(self.name)

implTypeMagic str:
  newPyString(fmt"<class '{self.name}'>")


proc getTypeDict*(obj: PyObject): PyDictObject = 
  PyDictObject(obj.pyType.dict)

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
    let msg = fmt"attribute name must be string, not {typeStr}"
    return newTypeError(msg)
  let name = PyStrObject(nameObj)
  let typeDict = self.getTypeDict
  if typeDict == nil:
    unreachable("for type object dict must not be nil")
  if typeDict.hasKey(name):
    let descr = typeDict[name]
    let descrGet = descr.pyType.magicMethods.get
    if descrGet.isNil:
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

# for internal objects
proc initTypeDict(tp: PyTypeObject) = 
  assert tp.dict.isNil
  let d = newPyDict()
  # magic methods. field loop syntax is pretty weird
  # no continue, no enumerate
  var i = 0
  for meth in tp.magicMethods.fields:
    if not meth.isNil:
      let namePyStr = newPyString(magicNames[i])
      if meth is BltinFunc:
        d[namePyStr] = newPyStaticMethod(newPyNimFunc(meth, namePyStr))
      else:
        d[namePyStr] = tp.newPyMethodDescr(meth, namePyStr)
    inc i
   
  # bltin methods
  for name, meth in tp.bltinMethods.pairs:
    let namePyStr = newPyString(name)
    d[namePyStr] = tp.newPyMethodDescr(meth, namePyStr)

  tp.dict = d

proc typeReady*(tp: PyTypeObject) = 
  tp.pyType = pyTypeObjectType
  tp.addGeneric
  if tp.dict.isNil:
    tp.initTypeDict

pyTypeObjectType.typeReady()


implTypeMagic call:
  # quoting CPython: "ugly exception". 
  # Deal with `type("abc") == str`, what a design failure.
  if (self == pyTypeObjectType) and (args.len == 1):
    return args[0].pyType

  let newFunc = self.magicMethods.New
  if newFunc.isNil:
    let msg = fmt"cannot create '{self.name}' instances because __new__ is not set"
    return newTypeError(msg)
  let newObj = newFunc(@[PyObject(self)] & args)
  if newObj.isThrownException:
    return newObj
  let initFunc = self.magicMethods.init
  if not initFunc.isNil:
    let initRet = newObj.initFunc(args)
    if initRet.isThrownException:
      return initRet
  return newObj


# create user defined class
# As long as relying on Nim GC it's hard to do something like variable length object
# in CPython, so we have to use a somewhat traditional and clumsy way
declarePyType Instance(dict):
  discard

# todo: should to the base object when inheritance and mro is ready
# todo: should support more complicated arg declaration
implInstanceMagic New(tp: PyTypeObject):
  result = new PyInstanceObject
  result.pyType = tp


implTypeMagic New(metaType: PyTypeObject, name: PyStrObject, 
                  bases: PyTupleObject, dict: PyDictObject):
  assert metaType == pyTypeObjectType
  let tp = newPyType(name.str)
  setDictOffset(Type)
  tp.tp = PyTypeToken.Type
  tp.magicMethods.New = newPyInstanceObject
  tp.dict = dict
  tp.typeReady
  tp

proc isClass*(obj: PyObject): bool {. cdecl .} = 
  obj.pyType.tp == PyTypeToken.Type
