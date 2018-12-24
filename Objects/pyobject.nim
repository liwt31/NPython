import macros
import strformat
import strutils
import hashes

import pyobjectBase
import exceptions

export macros
export pyobjectBase

template call*(obj: PyObject, methodName: untyped): PyObject = 
  let fun = obj.pyType.methods.methodName
  if fun == nil:
    let objTypeStr = $obj.pyType.name
    let methodStr = astToStr(methodName)
    newTypeError("No " & methodStr & " method for " & objTypeStr & " defined")
  else:
    fun(obj)

template call*(obj: PyObject, methodName: untyped, arg1: PyObject): PyObject = 
  let fun = obj.pyType.methods.methodName
  if fun == nil:
    let objTypeStr = $obj.pyType.name
    let methodStr = astToStr(methodName)
    newTypeError("No " & methodStr & " method for " & objTypeStr & " defined")
  else:
    fun(obj, arg1)

# some generic behaviors that every type should obey
proc And(o1, o2: PyObject): PyObject = 
  let b1 = o1.call(bool)
  let b2 = o2.call(bool)
  b1.call(And, b2)

proc Xor(o1, o2: PyObject): PyObject = 
  let b1 = o1.call(bool)
  let b2 = o2.call(bool)
  b1.call(Xor, b2)

proc Or(o1, o2: PyObject): PyObject = 
  let b1 = o1.call(bool)
  let b2 = o2.call(bool)
  b1.call(Or, b2)

proc le(o1, o2: PyObject): PyObject =
  let lt = o1.call(lt, o2)
  let eq = o1.call(eq, o2)
  lt.call(Or, eq)

proc ne(o1, o2: PyObject): PyObject =
  let eq = o1.call(eq, o2)
  eq.call(Not)

proc ge(o1, o2: PyObject): PyObject = 
  let gt = o1.call(gt, o2)
  let eq = o1.call(eq, o2)
  gt.call(Or, eq)

proc newPyType*(name: string): PyTypeObject =
  new result
  result.name = name
  result.methods.And = And
  result.methods.Xor = Xor
  result.methods.Or = Or
  result.methods.le = le
  result.methods.ne = ne
  result.methods.ge = ge


type 
  PyNone = ref object of PyObject


method `$`*(obj: PyNone): string =
  "None"

let pyNone* = new PyNone


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
          ident("methods")
        ),
        methodName
      ),
      name
    )
  )


proc impleUnary*(methodName, ObjectType, code:NimNode): NimNode = 
  let params = [ident("PyObject"), newIdentDefs(ident("selfNoCast"), ident("PyObject"))]
  result = genImple(methodName, ObjectType, code, params)


proc impleBinary*(methodName, ObjectType, code:NimNode): NimNode= 
  let poIdent = ident("PyObject")
  let params = [
                 poIdent, 
                 newIdentDefs(ident("selfNoCast"), poIdent),
                 newIdentDefs(ident("other"), poIdent)
               ]
  result = genImple(methodName, ObjectType, code, params)

