import strformat

import pyobject
import stringobject


type
  PyExceptionObject* = ref object of PyObject

  PySyntaxError* = ref object of PyExceptionObject

  PyNameError* = ref object of PyExceptionObject
    name: PyStringObject

  PyNotImplementedError* = ref object of PyExceptionObject
    msg: PyStringObject

  PyTypeError*  = ref object of PyExceptionObject
    msg: PyStringObject



proc newNameError*(name: PyStringObject) : PyNameError = 
  new result
  result.name = name


proc newNotImplementedError*(msg: PyStringObject) : PyNotImplementedError = 
  new result
  result.msg = msg 

proc newNotImplementedError*(msg: string) : PyNotImplementedError = 
  result = newNotImplementedError(newPyString(msg))

proc newTypeError*(msg: string): PyTypeError = 
  new result
  result.msg = newPyString(msg)

method `$`*(e: PyNameError): string = 
  fmt"name {e.name} is not defined"


method `$`*(e: PyNotImplementedError): string = 
  $e.msg


