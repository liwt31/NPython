import hashes

type 
  unaryFunc* = proc (o: PyObject): PyObject
  binaryFunc* = proc (o1, o2: PyObject): PyObject
  ternaryFunc* = proc (o1, o2, o3: PyObject): PyObject


  PyMethods = tuple
    add: binaryFunc
    substract: binaryFunc
    multiply: binaryFunc
    tryeDivide: binaryFunc
    power: binaryFunc

    bool: unaryFunc

    lt: binaryFunc
    le: binaryFunc
    eq: binaryFunc
    ne: binaryFunc
    gt: binaryFunc
    ge: binaryFunc


  PyObject* = ref object of RootObj
    pyType*: PyTypeObject


  PyTypeObject* = ref object of PyObject
    methods*: PyMethods

template call*(obj: PyObject, methodName: untyped): PyObject = 
  obj.pyType.methods.methodName(obj)

template call*(obj: PyObject, methodName: untyped, arg1: PyObject): PyObject = 
  obj.pyType.methods.methodName(obj, arg1)

template call*(obj: PyObject, methodName: untyped, arg1, arg2: PyObject): PyObject = 
  obj.pyType.methods.methodName(obj, arg1, arg2)

method `$`*(obj: PyObject): string {.base.} = 
  "Python object"

method hash*(obj: PyObject): Hash {.base.} = 
  hash(addr(obj[]))

method `==`*(obj1, obj2: PyObject): bool {.base.} =
  obj1[].addr == obj2[].addr


type 
  PyNone = ref object of PyObject


method `$`*(obj: PyNone): string =
  "None"

let pyNone* = new PyNone

