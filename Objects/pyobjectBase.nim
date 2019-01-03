import strformat
import strutils
import tables

import ../Utils/utils


type 
  # function prototypes, magic methods tuple, PyObject and PyTypeObject
  # rely on each other, so they have to be declared in the same `type`

  # these three function are used when number of arguments can be
  # directly obtained from OpCode
  UnaryMethod* = proc (self: PyObject): PyObject {. cdecl .}
  BinaryMethod* = proc (self, other: PyObject): PyObject {. cdecl .}
  TernaryMethod* = proc (self, arg1, arg2: PyObject): PyObject {. cdecl .}


  # for those that number of arguments unknown (and potentially kwarg?)
  BltinFunc* = proc (args: seq[PyObject]): PyObject {. cdecl .}
  BltinMethod* = proc (self: PyObject, args: seq[PyObject]): PyObject {. cdecl .}


  # modify their names in typeobject.nim when modify the magic methods
  MagicMethods = tuple
    add: BinaryMethod
    subtract: BinaryMethod
    multiply: BinaryMethod
    trueDivide: BinaryMethod
    floorDivide: BinaryMethod
    remainder: BinaryMethod
    power: BinaryMethod
    
    # use uppercase to avoid conflict with nim keywords
    Not: UnaryMethod
    negative: UnaryMethod
    positive: UnaryMethod
    absolute: UnaryMethod
    bool: UnaryMethod

    # note: these 3 are all bitwise operations, nothing to do with keywords `and` or `or`
    And: BinaryMethod
    Xor: BinaryMethod
    Or: BinaryMethod

    lt: BinaryMethod
    le: BinaryMethod
    eq: BinaryMethod
    ne: BinaryMethod
    gt: BinaryMethod
    ge: BinaryMethod

    len: UnaryMethod

    str: UnaryMethod
    repr: UnaryMethod

    new: BltinMethod
    init: BltinMethod
    getattr: BinaryMethod
    hash: UnaryMethod
    dict: UnaryMethod
    call: BltinMethod 

    getitem: BinaryMethod
    setitem: TernaryMethod

    # what to do when getting attribute of its intances
    get: BinaryMethod
    
    # what to do when iter, next is operating on its instances
    iter: UnaryMethod
    iternext: UnaryMethod


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




proc id*(obj: PyObject): int {. inline, cdecl .} = 
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

proc getDict*(obj: PyObject): PyObject {. cdecl .} = 
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
