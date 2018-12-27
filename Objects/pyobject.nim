import macros
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



proc impleMethod*(methodName, objectType, code:NimNode): NimNode = 
  let name = ident($methodName & $objectType)
  var typeObjName = $objectType & "Type"
  typeObjName[0] = typeObjName[0].toLowerAscii
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
        ident(typeObjName),
        newIdentNode("registerBltinMethod")
      ),
      newLit(methodName.strVal),
      name
    )
  )
