import typetraits
import strformat
import strutils
import tables

import pyobject
import bundle
import methodobject
import funcobjectImpl
import descrobject

import ../Utils/utils
import ../Python/neval

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
  if typeDict.isNil:
    unreachable("for type object dict must not be nil")
  var descr: PyObject
  if typeDict.hasKey(name):
    descr = typeDict[name]
    let descrGet = descr.pyType.magicMethods.get
    if not descrGet.isNil:
      return descr.descrGet(self)

  if self.hasDict:
    let instDict = PyDictObject(self.getDict)
    if instDict.hasKey(name):
      return instDict[name]

  if not descr.isNil:
    return descr

  return newAttributeError($self.pyType.name, $name)
  
# generic getattr
proc setAttr(self: PyObject, nameObj: PyObject, value: PyObject): PyObject {. cdecl .} =
  if not nameObj.ofPyStrObject:
    let typeStr = nameObj.pyType.name
    let msg = fmt"attribute name must be string, not {typeStr}"
    return newTypeError(msg)
  let name = PyStrObject(nameObj)
  let typeDict = self.getTypeDict
  if typeDict.isNil:
    unreachable("for type object dict must not be nil")
  var descr: PyObject
  if typeDict.hasKey(name):
    descr = typeDict[name]
    let descrSet = descr.pyType.magicMethods.set
    if not descrSet.isNil:
      return descr.descrSet(self, value)
      
  if self.hasDict:
    let instDict = PyDictObject(self.getDict)
    instDict[name] = value
    return pyNone

  return newAttributeError($self.pyType.name, $name)


proc addGeneric(t: PyTypeObject) = 
  template nilMagic(magicName): bool = 
    t.magicMethods.magicName.isNil

  template updateSlot(magicName, methodName) = 
    if nilMagic(magicName):
      t.magicMethods.magicName = methodName

  if (not nilMagic(lt)) and (not nilMagic(eq)):
    updateSlot(le, le)
  if (not nilMagic(eq)):
    updateSlot(ne, ne)
  if (not nilMagic(ge)) and (not nilMagic(eq)):
    updateSlot(ge, ge)
  updateSlot(getattr, getAttr)
  updateSlot(setattr, setAttr)
  updateSlot(str, strDefault)
  updateSlot(repr, reprDefault)

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
        d[namePyStr] = newPyMethodDescr(tp, meth, namePyStr)
    inc i
   
  # bltin methods
  for name, meth in tp.bltinMethods.pairs:
    let namePyStr = newPyString(name)
    d[namePyStr] = newPyMethodDescr(tp, meth, namePyStr)

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
    let initRet = initFunc(newObj, args)
    if initRet.isThrownException:
      return initRet
    # otherwise discard
  return newObj


# create user defined class
# As long as relying on Nim GC it's hard to do something like variable length object
# in CPython, so we have to use a somewhat traditional and clumsy way
declarePyType Instance(dict):
  discard

# todo: should move to the base object when inheritance and mro is ready
# todo: should support more complicated arg declaration
implInstanceMagic New(tp: PyTypeObject):
  result = newPyInstanceSimple()
  result.pyType = tp

implInstanceMagic init:
  let fun = self.getTypeDict[newPyStr("__init__")]
  if not fun.ofPyFunctionObject:
    return newTypeError("should use a function")
  # todo: setup the nil here, need a global state
  # or eliminate the nil and setup directly in `newPyFrame`?
  let newF = newPyFrame(PyFunctionObject(fun), @[PyObject(self)] & args, nil)
  PyFrameObject(newF).evalFrame

implTypeMagic New(metaType: PyTypeObject, name: PyStrObject, 
                  bases: PyTupleObject, dict: PyDictObject):
  assert metaType == pyTypeObjectType
  assert bases.len == 0
  let tp = newPyType(name.str)
  tp.tp = PyTypeToken.Type
  tp.dictOffset = pyInstanceObjectType.dictOffset
  tp.magicMethods.New = newPyInstanceObject
  if dict.hasKey(newPyStr("__init__")):
    tp.magicMethods.init = initPyInstanceObject
  tp.dict = PyDictObject(dict.copyPyDictObject())
  tp.typeReady
  tp

proc isClass*(obj: PyObject): bool {. cdecl .} = 
  obj.pyType.tp == PyTypeToken.Type
