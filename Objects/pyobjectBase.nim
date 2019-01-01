import strformat
import strutils
import hashes
import tables

import ../Utils/utils


type 
  # function prototypes, magic methods tuple, PyObject and PyTypeObject
  # rely on each other, so they have to be declared in the same `type`

  # these two function are used when number of arguments can be
  # directly obtained from OpCode
  UnaryFunc* = proc (self: PyObject): PyObject
  BinaryFunc* = proc (self, other: PyObject): PyObject


  # for those that number of arguments unknown (and potentially kwarg?)
  BltinFunc* = proc (args: seq[PyObject]): PyObject
  BltinMethod* = proc (self: PyObject, args: seq[PyObject]): PyObject


  # type-specfic alias
  DescrGet* = proc (descr, obj: PyObject): PyObject
  GetIterFunc* = proc (self: PyObject): PyObject
  IterNextFunc* = proc (self: PyObject): PyObject

  # modify their names in typeobject.nim when modify the magic methods
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

    len: UnaryFunc

    str: UnaryFunc
    repr: UnaryFunc

    getattr: BinaryFunc
    dict: UnaryFunc
    call: BltinMethod 
    new: BltinMethod
    init: BltinMethod

    # what to do when getting attribute of its intances
    descrGet: DescrGet
    
    # what to do when iter, next is operating on its instances
    iter: GetIterFunc
    iternext: IterNextFunc


  PyObject* = ref object of RootObj
    pyType*: PyTypeObject
    # the following fields are possible for a PyObject
    # depending on how you declare it (mutable, dict, etc)
    
    # prevent infinite recursion evaluating repr
    # reprLock*: bool
    
    # might be used to avoid GIL in the future?
    # a semaphore and a mutex...
    # but Nim has only thread local heap...
    # maybe interpreter level thread?
    # or real pthread but kind of read-only, then what's the difference with processes?
    # or both?
    # readNum*: int
    # writeLock*: bool
    #
    # dict*: PyDictObject


  PyTypeObject* = ref object of PyObject
    name*: string
    magicMethods*: MagicMethods
    bltinMethods*: Table[string, BltinMethod]

    # this is actually a PyDictObject. but we haven't defined dict yet.
    # the values are set in typeobject.nim when the type is ready
    dict*: PyObject

    # not offset of `PyTypeObject` itself 
    # but instances of this type 
    dictOffset*: int



method `$`*(obj: PyObject): string {.base, inline.} = 
  "Python object"


method hash*(obj: PyObject): Hash {.base, inline.} = 
  hash(addr(obj[]))


method `==`*(obj1, obj2: PyObject): bool {.base, inline.} =
  obj1[].addr == obj2[].addr

proc id*(obj: PyObject): int {. inline .} = 
  cast[int](obj[].addr)


proc idStr*(obj: PyObject): string {. inline .} = 
  fmt"{obj.id:#x}"


var bltinTypes*: seq[PyTypeObject]


proc newPyType*(name: string): PyTypeObject =
  new result
  result.name = name.toLowerAscii
  result.bltinMethods = initTable[string, BltinMethod]()
  result.dictOffset = -1
  bltinTypes.add(result)

proc getDict*(obj: PyObject): PyObject = 
  let tp = obj.pyType
  if tp.dictOffset < 0:
    unreachable("obj has no dict. Use hasDict before getDict")
  let dictPtr = cast[ptr PyObject](cast[int](obj[].addr) + tp.dictOffset)
  dictPtr[]



# todo: make it an object with type
type 
  PyNone = ref object of PyObject


method `$`*(obj: PyNone): string =
  "None"

let pyNone* = new PyNone
