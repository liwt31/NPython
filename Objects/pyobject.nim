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


include pyobjectBase
include exceptions
import ../Utils/utils

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


proc genImpl*(methodName, ObjectType, body:NimNode, params: varargs[NimNode]): NimNode= 

  result = newStmtList()
  let name = ident($methodName & $ObjectType)

  let procNode = newProc(name, params, body)
  procNode.addPragma(
    ident("readMethod")
  )
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


proc implUnary*(methodName, objectType, code:NimNode): NimNode = 
  let params = [ident("PyObject"), newIdentDefs(ident("selfNoCast"), ident("PyObject"))]
  result = genImpl(methodName, objectType, code, params)



proc implBinary*(methodName, objectType, code:NimNode): NimNode = 
  let poIdent = ident("PyObject")
  let params = [
                 poIdent, 
                 newIdentDefs(ident("selfNoCast"), poIdent),
                 newIdentDefs(ident("other"), poIdent)
               ]
  result = genImpl(methodName, objectType, code, params)


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

# here first argument is casted without checking
proc implMethod*(methodNamePrefix, objectType, argTypes: NimNode, body:NimNode): NimNode = 
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
      ident("PyObject"),
      nnkIdentDefs.newTree(
        ident("selfNoCast"),
        ident("PyObject"),
        newEmptyNode(),
      ),
      nnkIdentDefs.newTree(
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
    newStmtList(
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
