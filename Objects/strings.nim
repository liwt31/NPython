import pyobject


type
  PyStringObj* = ref object of PyObject
    str: string
