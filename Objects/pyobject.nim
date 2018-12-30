# the object file is devided into two parts. pyobjectBase.nim is for very basic and 
# generic pyobject behavior. pyobject.nim as for helper macros for object method
# definition
import macros except name
import sets
import sequtils
import strformat
import strutils
import hashes
import tables

import ../Utils/utils
import pyobjectBase

export macros except name
export pyobjectBase

include exceptions

template getFun*(obj: PyObject, fun, methodName: untyped) = 
  if obj.pyType == nil:
    unreachable("Py type not set")
  fun = obj.pyType.magicMethods.methodName
  if fun == nil:
    let objTypeStr = $obj.pyType.name
    let methodStr = astToStr(methodName)
    return newTypeError("No " & methodStr & " method for " & objTypeStr & " defined")


template callMagic*(obj: PyObject, methodName: untyped): PyObject = 
  var fun: UnaryFunc
  obj.getFun(fun, methodName)
  fun(obj)
  


template callMagic*(obj: PyObject, methodName: untyped, arg1: PyObject): PyObject = 
  var fun: BinaryFunc
  obj.getFun(fun, methodName)
  fun(obj, arg1)


proc callBltinMethod*(obj: PyObject, methodName: string, args: varargs[PyObject]): PyObject = 
  let methods = obj.pyType.bltinMethods
  if not methods.hasKey(methodName):
    unreachable # think about how to deal with the error
  var realArgs: seq[PyObject]
  for arg in args:
    realArgs.add arg
  methods[methodName](obj, realArgs)



proc registerBltinMethod*(t: PyTypeObject, name: string, fun: BltinMethod) = 
  if t.bltinMethods.hasKey(name):
    unreachable(fmt"Method {name} is registered twice for type {t.name}")
  t.bltinMethods[name] = fun

template readEnterTmpl = 
  if not self.readEnter:
    return newLockError("Read failed because object is been written.")

# unary methods and binary methods are supposed to be read-only
# add a guard to prevent write during read process
macro readMethod*(code: untyped): untyped = 
  code.body = nnkStmtList.newTree(
                getAst(readEnterTmpl()),
                nnkTryStmt.newTree(
                  code.body,
                  nnkFinally.newTree(
                    nnkStmtList.newTree(
                      nnkCall.newTree(
                        ident("readLeave"),
                        ident("self")
                      )
                    )
                  )
                )
              )
  code

# assert self type then cast
macro castSelf*(ObjectType: untyped, code: untyped): untyped = 
  code.body = newStmtList(
    nnkCommand.newTree(
      ident("assert"),
      nnkInfix.newTree(
        ident("of"),
        ident("selfNoCast"),
        ObjectType
      )
    ),
    newLetStmt(
      ident("self"),
      newCall(ObjectType, ident("selfNoCast"))
    ),
    code.body
  )
  code


proc genImpl*(methodName, ObjectType, body:NimNode, 
              params: openarray[NimNode],
              pragmas: seq[NimNode]): NimNode= 
  methodName.expectKind(nnkIdent)
  ObjectType.expectKind(nnkIdent)
  body.expectKind(nnkStmtList)

  result = newStmtList()
  let name = ident($methodName & $ObjectType)

  let procNode = newProc(name, params, body)
  procNode.addPragma(
    ident("readMethod")
  )
  for p in pragmas:
    procNode.addPragma(p)
  procNode.addPragma(
    nnkExprColonExpr.newTree(
      ident("castSelf"),
      ObjectType
    )
  )
  result.add(procNode)

  var typeObjName = $ObjectType & "Type"
  typeObjName[0] = typeObjName[0].toLowerAscii
  result.add(
    newAssignment(
      newDotExpr(
        newDotExpr(
          ident(typeObjName),
          ident("magicMethods")
        ),
        methodName
      ),
      name
    )
  )


proc getPragmas*(node: NimNode): seq[NimNode] = 
  node.expectKind(nnkBracket)
  for p in node.children:
    result.add p


proc implUnary*(methodName, objectType, code:NimNode, 
                pragmasBracket:NimNode): NimNode = 
  let params = [ident("PyObject"), newIdentDefs(ident("selfNoCast"), ident("PyObject"))]
  let pragmas = getPragmas(pragmasBracket)
  genImpl(methodName, objectType, code, params, pragmas)



proc implBinary*(methodName, objectType, code:NimNode,
                 pragmasBracket:NimNode): NimNode = 
  let params = [
                 ident("PyObject"), 
                 newIdentDefs(ident("selfNoCast"), ident("PyObject")),
                 newIdentDefs(ident("other"), ident("PyObject"))
               ]
  let pragmas = getPragmas(pragmasBracket)
  genImpl(methodName, objectType, code, params, pragmas)


proc objName2tpObjName(objName: string): string {. compileTime .} = 
  result = objName & "Type"
  result[0] = result[0].toLowerAscii


#  return `checkArgNum(1, "append")` like
proc checkArgNumNimNode(artNum: int, methodName:string): NimNode = 
  result = newCall(ident("checkArgNum"), 
                   newIntLitNode(artNum), 
                   newStrLitNode(methodName))


# for difinition like `i: PyIntObject`
# obj: i
# tp: PyIntObject like
# tpObj: pyIntObjectType like
template checkTypeTmpl(obj, tp, tpObj, methodName) = 
  # should use a more sophisticated way to judge type
  if not (obj of tp):
    let expected {. inject .} = tpObj.name
    let got {. inject .}= obj.pyType.name
    let mName {. inject .}= methodName
    let msg = fmt"{expected} is requred for {mName} (got {got})"
    return newTypeError(msg)

template declareVarTmpl(name, obj) = 
  let name {. inject .} = obj

template castTypeTmpl(name, tp, obj) = 
  let name {. inject .} = tp(obj)

proc checkArgTypes(methodName, argTypes: NimNode): NimNode = 
  result = newStmtList()
  let argNum = argTypes.len
  result.add(checkArgNumNimNode(argNum, methodName.strVal))
  for idx, child in argTypes:
    let obj = nnkBracketExpr.newTree(
      ident("args"),
      newIntLitNode(idx),
    )
    let name = child[0]
    let tp = child[1]
    if tp.strVal == "PyObject":  # won't bother checking 
      result.add(getAst(declareVarTmpl(name, obj)))
    if tp.strVal != "PyObject": 
      let tpObj = ident(objName2tpObjName(tp.strVal))
      let methodNameStrNode = newStrLitNode(methodName.strVal)
      result.add(getAst(checkTypeTmpl(obj, tp, tpObj, methodNameStrNode)))
      result.add(getAst(castTypeTmpl(name, tp, obj)))


template writeEnterTmpl = 
  if not self.writeEnter:
    return newLockError("Write failed because object is been read or written.")

proc implMethod*(methodNamePrefix, objectType, argTypes, body:NimNode): NimNode = 
  var methodName, enterNode, leaveNode: NimNode 
  if methodNamePrefix.kind == nnkPrefix:
    methodName = methodNamePrefix[1]
    enterNode = getAst(writeEnterTmpl())
    leaveNode = nnkCall.newTree(
      ident("writeLeave"),
      ident("self")
    )
  else:
    methodName = methodNamePrefix
    enterNode = getAst(readEnterTmpl())
    leaveNode = nnkCall.newTree(
      ident("readLeave"),
      ident("self")
    )

  let name = ident($methodName & $objectType)
  var typeObjName = objName2tpObjName($objectType)
  let typeObjNode = ident(typeObjName)
  let procNode = newProc(
    nnkPostFix.newTree(
      ident("*"),  # let other modules call without having to lookup in the dict
      name,
    ),
    [
      ident("PyObject"), # return value
      nnkIdentDefs.newTree( # first arg
        ident("selfNoCast"),
        ident("PyObject"),
        newEmptyNode(),
      ),
      nnkIdentDefs.newTree( # second arg
        newIdentNode("args"),
        nnkBracketExpr.newTree(
          ident("seq"),
          ident("PyObject")
        ),
        nnkPrefix.newTree(
          ident("@"),
          nnkBracket.newTree()
        )
      )
    ],
    newStmtList(  # the function body
      checkArgTypes(methodName, argTypes),
      enterNode,
      nnkTryStmt.newTree(
        body,
        nnkFinally.newTree(
          nnkStmtList.newTree(
            leaveNode
          )
        )
      )
    ),
  )
  procNode.addPragma(
    nnkExprColonExpr.newTree(
      ident("castSelf"),
      objectType
    )
  )

  result = newStmtList(
    procNode,
    nnkCall.newTree(
      nnkDotExpr.newTree(
        typeObjNode,
        newIdentNode("registerBltinMethod")
      ),
      newLit(methodName.strVal),
      name
    )
  )


proc reprEnter*(obj: PyObject): bool = 
  if obj.reprLock:
    return false
  else:
    obj.reprLock = true
    return true

proc reprLeave*(obj: PyObject) = 
  obj.reprLock = false

proc readEnter*(obj: PyObject): bool = 
  if not obj.writeLock:
    inc obj.readNum
    return true
  else:
    return false

proc readLeave*(obj: PyObject) = 
  dec obj.readNum

proc writeEnter*(obj: PyObject): bool = 
  if 0 < obj.readNum or obj.writeLock:
    return false
  else:
    obj.writeLock = true
    return true

proc writeLeave*(obj: PyObject) = 
  obj.writeLock = false


template methodMacroTmpl*(name: untyped, nameStr: string) = 
  const objNameStr = "Py" & nameStr & "Object"
  macro `impl name Unary`(methodName, code:untyped): untyped {. used .} = 
    implUnary(methodName, ident(objNameStr), code, nnkBracket.newTree())

  macro `impl name Unary`(methodName, pragmas, code:untyped): untyped {. used .} = 
    implUnary(methodName, ident(objNameStr), code, pragmas)

  macro `impl name Binary`(methodName, pragmas, code:untyped): untyped {. used .} = 
    implBinary(methodName, ident(objNameStr), code, pragmas)

  macro `impl name Binary`(methodName, code:untyped): untyped {. used .}= 
    implBinary(methodName, ident(objNameStr), code, nnkBracket.newTree())

  macro `impl name Method`(methodName, argTypes, code:untyped): untyped {. used .}= 
    implMethod(methodName, ident(objNameStr), argTypes, code)

  macro `impl name Method`(methodName, code:untyped): untyped {. used .}= 
    let argTypes = nnkPar.newTree()
    implMethod(methodName, ident(objNameStr), argTypes, code)


macro declarePyType*(prototype, fields: untyped): untyped = 
  prototype.expectKind(nnkCall)
  fields.expectKind(nnkStmtList)
  var mutable, dict, repr: bool
  for i in 1..<prototype.len:
    prototype[i].expectKind(nnkIdent)
    let property = prototype[i].strVal
    if property == "mutable":
      mutable = true
    elif property == "dict":
      dict = true
    elif property == "repr":
      repr = true
    else:
      error("unexpected property: " & property)

  let nameIdent = prototype[0]
  let fullNameIdent = ident("Py" & nameIdent.strVal & "Object")

  result = newStmtList()
  var reclist = nnkRecList.newTree()
  for field in fields.children:
    field.expectKind(nnkCall)
    let identDef = nnkIdentDefs.newTree(
      nnkPostFix.newTree(
        ident("*"),
        field[0],
      ),
      field[1][0],
      newEmptyNode()
    )
    reclist.add(identDef)
  # if mutable, etc, add fields here


  let decObjNode = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      nnkPostFix.newTree(
        ident("*"),
        fullNameIdent,
      ),
      newEmptyNode(),
      nnkRefTy.newTree(
        nnkObjectTy.newTree(
          newEmptyNode(),
          nnkOfInherit.newTree(
            ident("PyObject")
          ),
          recList
        )
      )
    )
  )
  result.add(decObjNode)

  template initTypeTmpl(name, nameStr) = 
    let `py name ObjectType`* {. inject .} = newPyType(nameStr)

  result.add(getAst(initTypeTmpl(nameIdent, nameIdent.strVal)))

  result.add(getAst(methodMacroTmpl(nameIdent, nameIdent.strVal)))

