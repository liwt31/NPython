import macros except name
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


proc genImple*(methodName, ObjectType, code:NimNode, params: openarray[NimNode]): NimNode= 

  result = newStmtList()
  let name = ident($methodName & $ObjectType)
  let body = newStmtList(
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
    code
  )

  result.add(newProc(name, params, body))

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



proc impleUnary*(methodName, objectType, code:NimNode): NimNode = 
  let params = [ident("PyObject"), newIdentDefs(ident("selfNoCast"), ident("PyObject"))]
  result = genImple(methodName, objectType, code, params)



proc impleBinary*(methodName, objectType, code:NimNode): NimNode = 
  let poIdent = ident("PyObject")
  let params = [
                 poIdent, 
                 newIdentDefs(ident("selfNoCast"), poIdent),
                 newIdentDefs(ident("other"), poIdent)
               ]
  result = genImple(methodName, objectType, code, params)


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
template checkType(obj, tp, tpObj, methodName) = 
  # should use a more sophisticated way to judge type
  if not (obj of tp):
    let expected {. inject .} = tpObj.name
    let got {. inject .}= obj.pyType.name
    let mName {. inject .}= methodName
    let msg = fmt"{expected} is requred for {mName} (got {got})"
    return newTypeError(msg)

template declareVar(name, obj) = 
  let name {. inject .} = obj

template castType(name, tp, obj) = 
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
      result.add(getAst(declareVar(name, obj)))
    if tp.strVal != "PyObject": 
      let tpObj = ident(objName2tpObjName(tp.strVal))
      let methodNameStrNode = newStrLitNode(methodName.strVal)
      result.add(getAst(checkType(obj, tp, tpObj, methodNameStrNode)))
      result.add(getAst(castType(name, tp, obj)))



# here first argument is casted without checking
proc impleMethod*(methodName, objectType, argTypes: NimNode, code:NimNode): NimNode = 
  let name = ident($methodName & $objectType)
  var typeObjName = objName2tpObjName($objectType)
  let typeObjNode = ident(typeObjName)
  result = newStmtList(
    nnkProcDef.newTree(
      nnkPostFix.newTree(
        ident("*"),
        name,
      ),
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
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
          newEmptyNode()
        )
      ),
      newEmptyNode(),
      newEmptyNode(),
      newStmtList(
        checkArgTypes(methodName, argTypes),
        nnkLetSection.newTree(
          nnkIdentDefs.newTree(
            ident("self"),
            newEmptyNode(),
            newCall(
              objectType,
              ident("selfNoCast")
            )
          )
        ),
        code,
      ),
    ),
    nnkCall.newTree(
      nnkDotExpr.newTree(
        typeObjNode,
        newIdentNode("registerBltinMethod")
      ),
      newLit(methodName.strVal),
      name
    )
  )
