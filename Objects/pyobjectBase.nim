#[
declare some types and base methods, useful methods in pyobject.nim and methodobject.nim
divide the file primarily for two reasons
* exception handling. in pyobject.nim exception is required, 
  however exception relies on PyObject
* cyclic dependence of type and builtinfunc
]#

import hashes
import tables

type 
  unaryFunc* = proc (o: PyObject): PyObject
  binaryFunc* = proc (o1, o2: PyObject): PyObject
  ternaryFunc* = proc (o1, o2, o3: PyObject): PyObject

  BltinFunc* = proc (args: seq[PyObject]): PyObject

  MagicMethods = tuple
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

    # note: these are all bitwise operations, nothing to do with keywords `and` or `or`
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
    magicMethods*: MagicMethods
    bltinMethods*: Table[string, BltinFunc]

  PyBltinFuncObject* = ref object of PyObject
    fun*: BltinFunc


method `$`*(obj: PyObject): string {.base.} = 
  "Python object"


method hash*(obj: PyObject): Hash {.base.} = 
  hash(addr(obj[]))


method `==`*(obj1, obj2: PyObject): bool {.base.} =
  obj1[].addr == obj2[].addr
