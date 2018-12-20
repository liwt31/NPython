import pyobject


type
  PyExceptionObject* = ref object of PyObject

  PySyntaxError* = ref object of PyExceptionObject
