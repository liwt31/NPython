# we use a completely different approach for error handling
# CPython relies on NULL as return value to inform the caller 
# that exception happens in that function. 
# Using NULL or nil as "expected" return value is bad idea
# let alone using global variables so
# we return exception object directly with a thrown flag inside

import strformat

import pyobject

type ExceptionToken {. pure .} = enum
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
  ZeroDivision,


declarePyType Exception(tpToken):
  tk: ExceptionToken
  thrown: bool
  msg: string


template newProcTmpl(name) = 
  proc `new name Error`*(msg:string, thrown=true): PyExceptionObject {. cdecl .} = 
    result = newPyExceptionSimple()
    result.tk = ExceptionToken.`name`
    result.thrown = thrown
    result.msg = msg

macro genNewProcs: untyped = 
  result = newStmtList()
  var tokenStr: string
  for i in ExceptionToken.low..ExceptionToken.high:
    let tokenStr = $ExceptionToken(i)
    result.add(getAst(newProcTmpl(ident(tokenStr))))


genNewProcs


proc newStopIterError*(thrown=true): PyExceptionObject {. cdecl .} = 
  result = newStopIterError("", thrown)


proc newAttributeError*(tpName, attrName: string): PyExceptionObject {. cdecl .} = 
  let msg = fmt"{tpName} has no attribute {attrName}"
  result = newStopIterError(msg, true)

proc newZeroDivisionError*: PyExceptionObject {. cdecl .} =
  newZeroDivisionError("integer division or modulo by zero")

proc isStopIter*(obj: PyObject): bool = 
  if not obj.ofPyExceptionObject:
    return false
  let excp = PyExceptionObject(obj)
  return (excp.tk == ExceptionToken.StopIter) and (excp.thrown)


method `$`*(e: PyExceptionObject): string = 
  $e.msg


template isThrownException*(pyObj: PyObject): bool = 
  if pyObj.ofPyExceptionObject:
    PyExceptionObject(pyObj).thrown
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


proc checkIterable*(obj: PyObject): PyObject = 
  let iterFunc = obj.pyType.magicMethods.iter
  if iterFunc == nil:
    return newTypeError(fmt"{obj.pyType.name} object is not iterable")
  let iterObj = iterFunc(obj)
  if iterObj.pyType.magicMethods.iternext == nil:
    let msg = fmt"iter() returned non-iterator of type {iterObj.pyType.name}"
    return newTypeError(msg)
  return iterobj


template checkArgNum*(expected: int, name="") = 
  if args.len != expected:
    var msg: string
    if name != "":
      msg = name & " takes exactly " & $expected & fmt" argument ({args.len} given)"
    else:
      msg = "expected " & $expected & fmt" argument ({args.len} given)"
    return newTypeError(msg)
