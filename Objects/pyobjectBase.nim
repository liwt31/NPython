# declare some types and base methods, useful methods in pyobjectImple
# divide the file primarily for exception handling. in pyobject.nim exception
# is required, however exception relies on PyObject

import hashes

type 
  unaryFunc* = proc (o: PyObject): PyObject
  binaryFunc* = proc (o1, o2: PyObject): PyObject
  ternaryFunc* = proc (o1, o2, o3: PyObject): PyObject


  PyMethods = tuple
    add: binaryFunc
    subtract: binaryFunc
    multiply: binaryFunc
    trueDivide: binaryFunc
    floorDivide: binaryFunc
    remainder: binaryFunc
    power: binaryFunc
    
    # use uppercase to avoid conflict with nim keywords
    Not: unaryFunc
    negative: unaryFunc
    positive: unaryFunc
    absolute: unaryFunc
    bool: unaryFunc

    And: binaryFunc
    Xor: binaryFunc
    Or: binaryFunc

    lt: binaryFunc
    le: binaryFunc
    eq: binaryFunc
    ne: binaryFunc
    gt: binaryFunc
    ge: binaryFunc

    str: unaryFunc
    repr: unaryFunc


  PyObject* = ref object of RootObj
    pyType*: PyTypeObject


  PyTypeObject* = ref object of PyObject
    name*: string
    methods*: PyMethods



method `$`*(obj: PyObject): string {.base.} = 
  "Python object"


method hash*(obj: PyObject): Hash {.base.} = 
  hash(addr(obj[]))


method `==`*(obj1, obj2: PyObject): bool {.base.} =
  obj1[].addr == obj2[].addr
