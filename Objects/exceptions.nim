import pyobject


type
  Exception* = ref object of PyObject

  SyntaxError* = ref object of Exception
