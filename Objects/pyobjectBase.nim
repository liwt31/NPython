import hashes
import tables

import pyobject

type 
  UnaryFunc* = proc (o: PyObject): PyObject
  BinaryFunc* = proc (o1, o2: PyObject): PyObject
  TernaryFunc* = proc (o1, o2, o3: PyObject): PyObject

  BltinFunc* = proc (args: seq[PyObject]): PyObject

  MagicMethods = tuple
    add: BinaryFunc
    subtract: BinaryFunc
    multiply: BinaryFunc
    trueDivide: BinaryFunc
    floorDivide: BinaryFunc
    remainder: BinaryFunc
    power: BinaryFunc
    
    # use uppercase to avoid conflict with nim keywords
    Not: UnaryFunc
    negative: UnaryFunc
    positive: UnaryFunc
    absolute: UnaryFunc
    bool: UnaryFunc

    # note: these are all bitwise operations, nothing to do with keywords `and` or `or`
    And: BinaryFunc
    Xor: BinaryFunc
    Or: BinaryFunc

    lt: BinaryFunc
    le: BinaryFunc
    eq: BinaryFunc
    ne: BinaryFunc
    gt: BinaryFunc
    ge: BinaryFunc

    str: UnaryFunc
    repr: UnaryFunc


  PyObject* = ref object of RootObj
    pyType*: PyTypeObject


  PyTypeObject* = ref object of PyObject
    name*: string
    magicMethods*: MagicMethods
    bltinMethods*: Table[string, BltinFunc]
    # this is actually a dict. but we haven't defined dict yet.
    # the values are set in typeobject.nim when the type is ready
    dict*: PyObject 


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




