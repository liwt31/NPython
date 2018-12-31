# we use a completely different approach for error handling
# CPython relies on NULL as return value to inform the caller 
# that exception happens in that function. 
# Using NULL or nil as "expected" return value is bad idea
# let alone using global variables so
# we return exception object directly with a thrown flag inside

import strformat

import pyobjectBase

# need a lot of work to expose these to upper NPython
# make a wrapper object should do (exceptionobjects.nim)
type
  PyExceptionObject* = ref object of PyObject
    thrown*: bool
    # use a string directly. Don't use PyStrObject
    # Exceptions are tightly binded to the core of NPython
    # reliance on PyStrObject inevitably induces cyclic dependence
    msg: string

  PyNameError* = ref object of PyExceptionObject

  PyNotImplementedError* = ref object of PyExceptionObject

  PyTypeError*  = ref object of PyExceptionObject

  PyAttributeError* = ref object of PyExceptionObject

  PyValueError* = ref object of PyExceptionObject

  PyIndexError* = ref object of PyExceptionObject

  PyStopIterError* = ref object of PyExceptionObject

  PyLockError* = ref object of PyExceptionObject

  PyImportError* = ref object of PyExceptionObject

# need some fine grained control here, so generic is not so good
# a little bit messy won't harm for now because 
# 1) the file is expected to be drasticly refactored 
#    when exposing exceptions to upper level interpreter
# 2) I need more experience on how excptions are used in the project to 
#    decide how to refactor this file

proc newNameError*(name:string, thrown=true) : PyNameError = 
  new result
  result.thrown = thrown
  result.msg = fmt"name {name} is not defined"


template implNew = 
  new result
  result.thrown = thrown
  result.msg = msg

proc newNotImplementedError*(msg: string, thrown=true) : PyNotImplementedError = 
  implNew


proc newTypeError*(msg: string, thrown=true): PyTypeError = 
  implNew


proc newAttributeError*(typeName, attrName: string, thrown=true): PyAttributeError =
  new result
  result.thrown = thrown
  result.msg = fmt"{typeName} object has no attribute {attrName}"


proc newValueError*(msg: string, thrown=true): PyValueError = 
  implNew


proc newIndexError*(msg: string, thrown=true): PyIndexError = 
  implNew

proc newStopIterError*: PyStopIterError = 
  new result
  result.thrown = true

proc newLockError*(msg: string, thrown=true): PyLockError = 
  implNew

proc isStopIter*(obj: PyObject): bool = 
  if obj of PyStopIterError:
    return PyStopIterError(obj).thrown
  false

proc newImportError*(msg: string, thrown=true): PyImportError = 
  implNew


method `$`*(e: PyExceptionObject): string = 
  $e.msg


template isThrownException*(pyObj: PyObject): bool = 
  if pyObj of PyExceptionObject:
    PyExceptionObject(pyObj).thrown
  else:
    false


template errorIfNotString*(pyObj: untyped, methodName: string) = 
    if not pyObj.isPyStringType:
      let typeName {. inject .} = pyObj.pyType.name
      let msg = methodName & fmt" returned non-string (type {typeName})"
      return newTypeError(msg)

template errorIfNotBool*(pyObj: untyped, methodName: string) = 
    if not pyObj.isPyBoolType:
      let typeName {. inject .} = pyObj.pyType.name
      let msg = methodName & fmt" returned non-bool (type {typeName})"
      return newTypeError(msg)



template checkArgNum*(expected: int, name="") = 
  if args.len != expected:
    var msg: string
    if name != "":
      msg = name & " takes exactly " & $expected & fmt" argument ({args.len} given)"
    else:
      msg = "expected " & $expected & fmt" argument ({args.len} given)"
    return newTypeError(msg)
