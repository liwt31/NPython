import macros
import sequtils
import strformat
import strutils
import hashes
import tables

include pyobjectBase
include exceptions
import ../Utils/utils


template callMagic*(obj: PyObject, methodName: untyped): PyObject = 
  let fun = obj.pyType.magicMethods.methodName
  if fun == nil:
    let objTypeStr = $obj.pyType.name
    let methodStr = astToStr(methodName)
    newTypeError("No " & methodStr & " method for " & objTypeStr & " defined")
  else:
    fun(obj)


template callMagic*(obj: PyObject, methodName: untyped, arg1: PyObject): PyObject = 
  let fun = obj.pyType.magicMethods.methodName
  if fun == nil:
    let objTypeStr = $obj.pyType.name
    let methodStr = astToStr(methodName)
    newTypeError("No " & methodStr & " method for " & objTypeStr & " defined")
  else:
    fun(obj, arg1)


proc callBltin*(obj: PyObject, methodName: string, args: varargs[PyObject]): PyObject = 
  let methods = obj.pyType.bltinMethods
  if not methods.hasKey(methodName):
    unreachable # think about how to deal with the error
  var realArgs = @[obj] 
  for arg in args:
    realArgs.add arg
  methods[methodName](realArgs)


# some generic behaviors that every type should obey
proc And(o1, o2: PyObject): PyObject = 
  let b1 = o1.callMagic(bool)
  let b2 = o2.callMagic(bool)
  b1.callMagic(And, b2)

proc Xor(o1, o2: PyObject): PyObject = 
  let b1 = o1.callMagic(bool)
  let b2 = o2.callMagic(bool)
  b1.callMagic(Xor, b2)

proc Or(o1, o2: PyObject): PyObject = 
  let b1 = o1.callMagic(bool)
  let b2 = o2.callMagic(bool)
  b1.callMagic(Or, b2)

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


var bltinTypes*: seq[PyTypeObject]


proc newPyType*(name: string, bltin=true): PyTypeObject =
  new result
  result.name = name
  var m = result.magicMethods
  m.And = And
  m.Xor = Xor
  m.Or = Or
  m.le = le
  m.ne = ne
  m.ge = ge
  result.bltinMethods = initTable[string, BltinFunc]()
  if bltin:
    bltinTypes.add(result)


proc registerBltinMethod*(t: PyTypeObject, name: string, fun: BltinFunc) = 
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
      name,
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
        ident("PyObject"),
        nnkIdentDefs.newTree(
          newIdentNode("args"),
          nnkBracketExpr.newTree(
            newIdentNode("seq"),
            newIdentNode("PyObject")
          ),
          newEmptyNode()
        )
      ),
      newEmptyNode(),
      newEmptyNode(),
      newStmtList(
        nnkLetSection.newTree(
          newIdentDefs(
            ident("self"),
            newEmptyNode(),
            newCall(
              objectType,
              nnkBracketExpr.newTree(
                ident("args"),
                newIntLitNode(0)
              )
            )
          )
        ),
        code,
      )
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
