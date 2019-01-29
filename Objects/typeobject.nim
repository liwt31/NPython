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
import ../Python/call


var magicNameStrs: seq[PyStrObject]
for name in magicNames:
  magicNameStrs.add newPyStr(name)

# PyTypeObject is manually declared in pyobjectBase.nim
# here we need to do some initialization
methodMacroTmpl(Type)


let pyTypeObjectType* = newPyType("type")
setDictOffset(Type)
pyTypeObjectType.kind = PyTypeToken.Type


implTypeMagic repr:
  newPyString(self.name)

implTypeMagic str:
  newPyString(fmt"<class '{self.name}'>")


proc getTypeDict*(obj: PyObject): PyDictObject = 
  PyDictObject(obj.pyType.dict)

# some generic behaviors that every type should obey
proc defaultLe(o1, o2: PyObject): PyObject {. cdecl .} =
  let lt = o1.callMagic(lt, o2)
  let eq = o1.callMagic(eq, o2)
  lt.callMagic(Or, eq)

proc defaultNe(o1, o2: PyObject): PyObject {. cdecl .} =
  let eq = o1.callMagic(eq, o2)
  eq.callMagic(Not)

proc defaultGe(o1, o2: PyObject): PyObject {. cdecl .} = 
  let gt = o1.callMagic(gt, o2)
  let eq = o1.callMagic(eq, o2)
  gt.callMagic(Or, eq)

proc reprDefault(self: PyObject): PyObject {. cdecl .} = 
  newPyString(fmt"<{self.pyType.name} at {self.idStr}>")

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

  template trySetSlot(magicName, defaultMethod) = 
    if nilMagic(magicName):
      t.magicMethods.magicName = defaultMethod

  if (not nilMagic(lt)) and (not nilMagic(eq)):
    trySetSlot(le, defaultLe)
  if (not nilMagic(eq)):
    trySetSlot(ne, defaultNe)
  if (not nilMagic(ge)) and (not nilMagic(eq)):
    trySetSlot(ge, defaultGe)
  trySetSlot(getattr, getAttr)
  trySetSlot(setattr, setAttr)
  trySetSlot(repr, reprDefault)
  trySetSlot(str, t.magicMethods.repr)


# for internal objects
proc initTypeDict(tp: PyTypeObject) = 
  assert tp.dict.isNil
  let d = newPyDict()
  # magic methods. field loop syntax is pretty weird
  # no continue, no enumerate
  var i = -1
  for meth in tp.magicMethods.fields:
    inc i
    if not meth.isNil:
      let namePyStr = magicNameStrs[i]
      if meth is BltinFunc:
        d[namePyStr] = newPyStaticMethod(newPyNimFunc(meth, namePyStr))
      else:
        d[namePyStr] = newPyMethodDescr(tp, meth, namePyStr)
   
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
  # Deal with `type("abc") == str`. What a design failure.
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
# The type declared here is never used, it's needed as a placeholder to declare magic
# methods.
declarePyType Instance(dict):
  discard


# todo: should move to the base object when inheritance and mro is ready
# todo: should support more complicated arg declaration
implInstanceMagic New(tp: PyTypeObject, *actualArgs):
  result = newPyInstanceSimple()
  result.pyType = tp

template instanceUnaryMethodTmpl(idx: int, nameIdent: untyped) = 
  implInstanceMagic nameIdent:
    let magicNameStr = magicNameStrs[idx]
    let fun = self.getTypeDict[magicNameStr]
    return fun.fastCall(@[PyObject(self)])

template instanceBinaryMethodTmpl(idx: int, nameIdent: untyped) = 
  implInstanceMagic nameIdent:
    let magicNameStr = magicNameStrs[idx]
    let fun = self.getTypeDict[magicNameStr]
    return fun.fastCall(@[PyObject(self), other])

template instanceTernaryMethodTmpl(idx: int, nameIdent: untyped) = 
  implInstanceMagic nameIdent:
    let magicNameStr = magicNameStrs[idx]
    let fun = self.getTypeDict[magicNameStr]
    return fun.fastCall(@[PyObject(self), arg1, arg2])

template instanceBltinFuncTmpl(idx: int, nameIdent: untyped) = 
  implInstanceMagic nameIdent:
    let magicNameStr = magicNameStrs[idx]
    let fun = self.getTypeDict[magicNameStr]
    return fun.fastCall(args)

template instanceBltinMethodTmpl(idx: int, nameIdent: untyped) = 
  implInstanceMagic nameIdent:
    let magicNameStr = magicNameStrs[idx]
    let fun = self.getTypeDict[magicNameStr]
    return fun.fastCall(@[PyObject(self)] & args)

macro implInstanceMagics: untyped = 
  result = newStmtList()
  var idx = -1
  var m: MagicMethods
  for name, v in m.fieldpairs:
    inc idx
    # no `continue` can be used...
    if name != "New":
      if v is UnaryMethod:
        result.add getAst(instanceUnaryMethodTmpl(idx, ident(name)))
      elif v is BinaryMethod:
        result.add getAst(instanceBinaryMethodTmpl(idx, ident(name)))
      elif v is TernaryMethod:
        result.add getAst(instanceTernaryMethodTmpl(idx, ident(name)))
      elif v is BltinFunc:
        result.add getAst(instanceBltinFuncTmpl(idx, ident(name)))
      elif v is BltinMethod:
        result.add getAst(instanceBltinMethodTmpl(idx, ident(name)))
      else:
        assert false

implInstanceMagics

template updateSlotTmpl(idx: int, slotName: untyped) = 
  let magicNameStr = magicNameStrs[idx]
  if dict.hasKey(magicnameStr):
    tp.magicMethods.`slotName` = tpMagic(Instance, slotname)

macro updateSlots(tp: PyTypeObject, dict: PyDictObject): untyped = 
  result = newStmtList()
  var idx = -1
  var m: MagicMethods
  for name, v in m.fieldpairs:
    inc idx
    result.add getAst(updateSlotTmpl(idx, ident(name)))

implTypeMagic New(metaType: PyTypeObject, name: PyStrObject, 
                  bases: PyTupleObject, dict: PyDictObject):
  assert metaType == pyTypeObjectType
  assert bases.len == 0
  let tp = newPyType(name.str)
  tp.kind = PyTypeToken.Type
  tp.dictOffset = pyInstanceObjectType.dictOffset
  tp.magicMethods.New = tpMagic(Instance, new)
  if dict.hasKey(newPyStr("__init__")):
    tp.magicMethods.init = tpMagic(Instance, init)
  updateSlots(tp, dict)
  tp.dict = PyDictObject(dict.copyPyDictObjectMethod())
  tp.typeReady
  tp
