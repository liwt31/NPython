# we use a completely different approach for error handling
# CPython relies on NULL as return value to inform the caller 
# that exception happens in that function. 
# Using NULL or nil as "expected" return value is bad idea
# let alone using global variables so
# we return exception object directly with a thrown flag inside

import strformat

import pyobject
import noneobject

type ExceptionToken* {. pure .} = enum
  Base,
  Name,
  NotImplemented,
  Type,
  Attribute,
  Value,
  Index,
  StopIter,
  Lock,
  Import,
  UnboundLocal,
  Key,
  Assertion


declarePyType BaseError(tpToken):
  tk: ExceptionToken
  thrown: bool
  msg: PyObject # could be nil


type
  PyExceptionObject* = PyBaseErrorObject


proc ofPyExceptionObject*(obj: PyObject): bool = 
  obj.ofPyBaseErrorObject


macro declareErrors: untyped = 
  result = newStmtList()
  var tokenStr: string
  for i in 1..int(ExceptionToken.high):
    let tokenStr = $ExceptionToken(i)

    let typeNode = nnkStmtList.newTree(
      nnkCommand.newTree(
        newIdentNode("declarePyType"),
        nnkCall.newTree(
          newIdentNode(tokenStr & "Error"),
          nnkCall.newTree(
            newIdentNode("base"),
            newIdentNode("BaseError")
          )
        ),
        nnkStmtList.newTree(
          nnkDiscardStmt.newTree(
            newEmptyNode()
          )
        )
      )
    )

    result.add(typeNode)

    template addTpTmpl(name) = 
      `py name ErrorObjectType`.tp = PyTypeToken.BaseError

    result.add(getAst(addTpTmpl(ident(tokenStr))))



declareErrors


template newProcTmpl(name) = 
  # use template for lazy evaluation to use PyString
  # theses two templates are used internally to generate errors
  template `new name Error`*: PyBaseErrorObject = 
    let excp = newPyBaseErrorSimple()
    excp.tk = ExceptionToken.`name`
    excp.thrown = true
    excp

  template `new name Error`*(msgStr:string): PyBaseErrorObject = 
    let excp = newPyBaseErrorSimple()
    excp.tk = ExceptionToken.`name`
    excp.thrown = true
    excp.msg = newPyString(msgStr)
    excp


macro genNewProcs: untyped = 
  result = newStmtList()
  var tokenStr: string
  for i in ExceptionToken.low..ExceptionToken.high:
    let tokenStr = $ExceptionToken(i)
    result.add(getAst(newProcTmpl(ident(tokenStr))))


genNewProcs


template newAttributeError*(tpName, attrName: string): PyExceptionObject = 
  let msg = tpName & " has no attribute " & attrName
  newAttributeError(msg)

proc isStopIter*(obj: PyObject): bool = 
  if not obj.ofPyExceptionObject:
    return false
  let excp = PyExceptionObject(obj)
  return (excp.tk == ExceptionToken.StopIter) and (excp.thrown)


method `$`*(e: PyExceptionObject): string = 
  result = "Error: " & $e.tk & " "
  if not e.msg.isNil:
    result &= $e.msg



template isThrownException*(pyObj: PyObject): bool = 
  if pyObj.ofPyExceptionObject:
    cast[PyExceptionObject](pyObj).thrown
  else:
    false


template errorIfNotString*(pyObj: untyped, methodName: string) = 
    if not pyObj.ofPyStrObject:
      let typeName {. inject .} = pyObj.pyType.name
      let msg = methodName & fmt" returned non-string (type {typeName})"
      return newTypeError(msg)

template errorIfNotBool*(pyObj: untyped, methodName: string) = 
    if not pyObj.ofPyBoolObject:
      let typeName {. inject .} = pyObj.pyType.name
      let msg = methodName & fmt" returned non-bool (type {typeName})"
      return newTypeError(msg)


template checkIterable*(obj: PyObject): PyObject = 
  let iterFunc = obj.pyType.magicMethods.iter
  if iterFunc == nil:
    let msg = obj.pyType.name & " object is not iterable"
    return newTypeError(msg)
  let iterObj = iterFunc(obj)
  if iterObj.pyType.magicMethods.iternext == nil:
    let msg = fmt"iter() returned non-iterator of type " & iterObj.pyType.name
    return newTypeError(msg)
  iterobj


template checkArgNum*(expected: int, name="") = 
  if args.len != expected:
    var msg: string
    if name != "":
      msg = name & " takes exactly " & $expected & fmt" argument ({args.len} given)"
    else:
      msg = "expected " & $expected & fmt" argument ({args.len} given)"
    return newTypeError(msg)

