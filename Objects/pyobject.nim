# the object file is devided into two parts. pyobjectBase.nim is for very basic and 
# generic pyobject behavior. pyobject.nim is for helpful macros for object method
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

template getFun*(obj: PyObject, methodName: untyped):untyped = 
  if obj.pyType == nil:
    unreachable("Py type not set")
  let fun = obj.pyType.magicMethods.methodName
  if fun == nil:
    let objTypeStr = $obj.pyType.name
    let methodStr = astToStr(methodName)
    return newTypeError("No " & methodStr & " method for " & objTypeStr & " defined")
  fun


#XXX: `obj` is used twice so it better be a simple identity
# if it's a function then the function is called twice!
template callMagic*(obj: PyObject, methodName: untyped): PyObject = 
  let fun = obj.getFun(methodName)
  fun(obj)
  
template callMagic*(obj: PyObject, methodName: untyped, arg1: PyObject): PyObject = 
  let fun = obj.getFun(methodName)
  fun(obj, arg1)


proc registerBltinMethod*(t: PyTypeObject, name: string, fun: BltinMethod) = 
  if t.bltinMethods.hasKey(name):
    unreachable(fmt"Method {name} is registered twice for type {t.name}")
  t.bltinMethods[name] = fun


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
              pragmas: NimNode): NimNode= 
  methodName.expectKind(nnkIdent)
  ObjectType.expectKind(nnkIdent)
  body.expectKind(nnkStmtList)
  pragmas.expectKind(nnkBracket)

  result = newStmtList()
  let name = ident($methodName & $ObjectType)

  let procNode = newProc(name, params, body)
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


proc implUnary*(methodName, objectType, code:NimNode, 
                pragmasBracket:NimNode): NimNode = 
  let params = [ident("PyObject"), newIdentDefs(ident("selfNoCast"), ident("PyObject"))]
  genImpl(methodName, objectType, code, params, pragmasBracket)



proc implBinary*(methodName, objectType, code:NimNode,
                 pragmasBracket:NimNode): NimNode = 
  let params = [
                 ident("PyObject"), 
                 newIdentDefs(ident("selfNoCast"), ident("PyObject")),
                 newIdentDefs(ident("other"), ident("PyObject"))
               ]
  genImpl(methodName, objectType, code, params, pragmasBracket)


proc objName2tpObjName(objName: string): string {. compileTime .} = 
  result = objName & "Type"
  result[0] = result[0].toLowerAscii


#  return `checkArgNum(1, "append")` like
proc checkArgNumNimNode(artNum: int, methodName:string): NimNode = 
  result = newCall(ident("checkArgNum"), 
                   newIntLitNode(artNum), 
                   newStrLitNode(methodName))


# example here: For a definition like `i: PyIntObject`
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


macro checkArgTypes*(nameAndArg, code: untyped): untyped = 
  let methodName = nameAndArg[0]
  let argTypes = nameAndArg[1]
  let body = newStmtList()
  let argNum = argTypes.len
  body.add(checkArgNumNimNode(argNum, methodName.strVal))
  for idx, child in argTypes:
    let obj = nnkBracketExpr.newTree(
      ident("args"),
      newIntLitNode(idx),
    )
    let name = child[0]
    let tp = child[1]
    if tp.strVal == "PyObject":  # won't bother checking 
      body.add(quote do:
          let `name` = `obj`
      )
    if tp.strVal != "PyObject": 
      let tpObj = ident(objName2tpObjName(tp.strVal))
      let methodNameStrNode = newStrLitNode(methodName.strVal)
      body.add(getAst(checkTypeTmpl(obj, tp, tpObj, methodNameStrNode)))
      body.add(quote do:
        let `name` = `tp`(`obj`)
      )
  body.add(code.body)
  code.body = body
  code



proc getNameAndArgTypes(prototype: NimNode): (NimNode, NimNode) = 
  let argTypes = nnkPar.newTree()
  let methodName = prototype[0]
  if prototype.kind == nnkObjConstr:
    for i in 1..<prototype.len:
      argTypes.add prototype[i]
  elif prototype.kind == nnkCall:
    discard # empty arg list
  elif prototype.kind == nnkPrefix:
    error("got prefix prototype, forget to declare object as mutable?")
  else:
    error("got prototype: " & prototype.treeRepr)

  (methodName, argTypes)


proc implMethod*(prototype, objectType, body, pragmas: NimNode): NimNode = 
  var (methodName, argTypes) = getNameAndArgTypes(prototype)
  let name = ident($methodName & $objectType)
  var typeObjName = objName2tpObjName($objectType)
  let typeObjNode = ident(typeObjName)

  let procNode = newProc(
    nnkPostFix.newTree(
      ident("*"),  # let other modules call without having to lookup in the type dict
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
    body, # the function body
  )
  # add pragmas, the last to add is the first to execute
  for p in pragmas:
    procNode.addPragma(p)

  procNode.addPragma(
    nnkExprColonExpr.newTree(
      ident("castSelf"),
      objectType
    )
  )

  procNode.addPragma(
    nnkExprColonExpr.newTree(
      ident("checkArgTypes"),
      nnkPar.newTree(
        methodName,
        argTypes
      ) 
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

  

macro hasReprLock*(methodName, code: untyped): untyped = 
  let reprEnter = quote do:
    if self.reprLock:
      return newPyString("...")
    self.reprLock = true

  let reprLeave = quote do: 
    self.reprLock = false

  if methodName.strVal != "repr":
    return code
  code.body = newStmtList( 
      reprEnter,
      nnkTryStmt.newTree(
        code.body,
        nnkFinally.newTree(
          nnkStmtList.newTree(
            reprLeave
          )
        )
      )
    )
  code


macro mutable*(kind, code: untyped): untyped = 
  if kind.strVal != "read" and kind.strVal != "write":
    error("got mutable pragma arg: " & kind.strVal)
  var enterNode, leaveNode: NimNode
  if kind.strVal == "write":
    enterNode = quote do:
      if 0 < self.readNum or self.writeLock:
        return newLockError("Write failed because object is been read or written.")
      self.writeLock = true
    leaveNode = quote do:
        self.writeLock = false
  else:
    enterNode = quote do:
      if self.writeLock:
        return newLockError("Read failed because object is been written.")
      inc self.readNum
    leaveNode = quote do:
      dec self.readNum
  code.body = nnkStmtList.newTree(
                enterNode,
                nnkTryStmt.newTree(
                  code.body,
                  nnkFinally.newTree(
                    nnkStmtList.newTree(
                      leaveNode
                    )
                  )
                )
              )
  code

proc getMutableReadPragma*: NimNode = 
  nnkExprColonExpr.newTree(
    ident("mutable"),
    ident("read")
  )

proc getMutableWritePragma*: NimNode = 
  nnkExprColonExpr.newTree(
    ident("mutable"),
    ident("write")
  )

# generate macros useful for function defination
template methodMacroTmpl*(name: untyped, nameStr: string, 
                          mutable=false, reprLock=false) = 
  const objNameStr = "Py" & nameStr & "Object"

  macro `impl name Unary`(methodName, pragmas, code:untyped): untyped {. used .} = 
    # currently consider all magic methods as read-only methods
    when mutable:
      pragmas.add(getMutableReadPragma())

    when reprLock:
      pragmas.add(
        nnkExprColonExpr.newTree(
          ident("hasReprLock"),
          methodName
        )
      )
    implUnary(methodName, ident(objNameStr), code, pragmas)

  # default args won't work here, so use overload
  macro `impl name Unary`(methodName, code:untyped): untyped {. used .} = 
    getAst(`impl name Unary`(methodName, nnkBracket.newTree(), code))

  macro `impl name Binary`(methodName, pragmas, code:untyped): untyped {. used .} = 
    when mutable:
      pragmas.add(getMutableReadPragma())
    implBinary(methodName, ident(objNameStr), code, pragmas)

  macro `impl name Binary`(methodName, code:untyped): untyped {. used .}= 
    getAst(`impl name Binary`(methodName, nnkBracket.newTree(), code))

  macro `impl name Method`(prototype, pragmas, code:untyped): untyped {. used .}= 
    when mutable:
      if prototype.kind == nnkPrefix: # indication of a write method
        pragmas.add(getMutableWritePragma())
        result = implMethod(prototype[1], ident(objNameStr), code, pragmas)
      else:
        pragmas.add(getMutableReadPragma())
        result = implMethod(prototype, ident(objNameStr), code, pragmas)
    else:
      result = implMethod(prototype, ident(objNameStr), code, pragmas)

  macro `impl name Method`(prototype, code:untyped): untyped {. used .}= 
    getAst(`impl name Method`(prototype, nnkBracket.newTree(), code))


macro declarePyType*(prototype, fields: untyped): untyped = 
  prototype.expectKind(nnkCall)
  fields.expectKind(nnkStmtList)
  var mutable, dict, reprLock: bool
  for i in 1..<prototype.len:
    prototype[i].expectKind(nnkIdent)
    let property = prototype[i].strVal
    if property == "mutable":
      mutable = true
    elif property == "dict":
      dict = true
    elif property == "reprLock":
      reprLock = true
    else:
      error("unexpected property: " & property)

  let nameIdent = prototype[0]
  let fullNameIdent = ident("Py" & nameIdent.strVal & "Object")

  result = newStmtList()
  var reclist = nnkRecList.newTree()
  proc addField(recList, name, tp: NimNode)=
    let newField = nnkIdentDefs.newTree(
      nnkPostFix.newTree(
        ident("*"),
        name
      ),
      tp,
      newEmptyNode()
    )  
    recList.add(newField)

  for field in fields.children:
    field.expectKind(nnkCall)
    reclist.addField(field[0], field[1][0])

  if reprLock:
    reclist.addField(ident("reprLock"), ident("bool"))
  if dict:
    # declare as PyObject to avoid cyclic Dependence on 
    reclist.addField(ident("dict"), ident("PyDictObject"))
  if mutable:
    reclist.addField(ident("readNum"), ident("int"))
    reclist.addField(ident("writeLock"), ident("bool"))

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

  template initTypeTmpl(name, nameStr, hasDict) = 
    let `py name ObjectType`* {. inject .} = newPyType(nameStr, hasDict)

  result.add(getAst(initTypeTmpl(nameIdent, nameIdent.strVal, newLit(dict))))


  result.add(getAst(methodMacroTmpl(nameIdent, nameIdent.strVal, 
                                    newLit(mutable), newLit(reprLock))))

