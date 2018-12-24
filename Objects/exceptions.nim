# we use a completely different approach for error handling
# CPython relies on NULL as return value to inform the caller 
# that exception happens in that function. 
# Using NULL or nil as "expected" return value is bad idea
# We return exception object directly with a thrown flag inside

import strformat

import pyobjectBase


type
  PyExceptionObject* = ref object of PyObject
    # use a string directly. Don't use PyStringObject
    # Exceptions are tightly binded to the core of NPython
    # reliance on PyStringObject inevitably induces cyclic dependence
    thrown*: bool
    msg: string

  PyNameError* = ref object of PyExceptionObject

  PyNotImplementedError* = ref object of PyExceptionObject

  PyTypeError*  = ref object of PyExceptionObject



proc newNameError*(name:string, thrown=true) : PyNameError = 
  new result
  result.thrown = thrown
  result.msg = fmt"name {name} is not defined"


proc newNotImplementedError*(msg: string, thrown=true) : PyNotImplementedError = 
  new result
  result.thrown = thrown
  result.msg = msg


proc newTypeError*(msg: string, thrown=true): PyTypeError = 
  new result
  result.thrown = thrown
  result.msg = msg


method `$`*(e: PyExceptionObject): string = 
  $e.msg

template isThrownException*(pyObj: PyObject): bool = 
  if pyObj of PyExceptionObject:
    PyExceptionObject(pyObj).thrown
  else:
    false

