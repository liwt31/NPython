import strformat
import strutils
import hashes
import tables


type 
  # these two function types are types that number of arguments can be
  # directly obtained from OpCode
  UnaryFunc* = proc (o: PyObject): PyObject
  BinaryFunc* = proc (o1, o2: PyObject): PyObject

  # for those that number of arguments unknown (and potentially kwarg?)
  BltinFunc* = proc (args: seq[PyObject]): PyObject
  BltinMethod* = proc (self: PyObject, args: seq[PyObject]): PyObject


  DescrGet* = proc (descr, obj: PyObject): PyObject
  GetIterFunc* = proc (self: PyObject): PyObject
  IterNextFunc* = proc (self: PyObject): PyObject

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


  PyTypeObject* = ref object of PyObject
    name*: string
    magicMethods*: MagicMethods
    bltinMethods*: Table[string, BltinMethod]
    # not whether `PyTypeObject` itself has dict, 
    # but whether instances of this type has dict
    hasDict: bool
    # this is actually a dict. but we haven't defined dict yet.
    # the values are set in typeobject.nim when the type is ready
    dict*: PyObject
    descrGet*: DescrGet
    iter*: GetIterFunc
    iternext*: IterNextFunc


method `$`*(obj: PyObject): string {.base.} = 
  "Python object"


method hash*(obj: PyObject): Hash {.base.} = 
  hash(addr(obj[]))


method `==`*(obj1, obj2: PyObject): bool {.base.} =
  obj1[].addr == obj2[].addr

proc id*(obj: PyObject): int = 
  cast[int](obj[].addr)


proc idStr*(obj: PyObject): string = 
  fmt"{obj.id:#x}"


var bltinTypes*: seq[PyTypeObject]


proc newPyType*(name: string, hasDict=false): PyTypeObject =
  new result
  result.name = name.toLowerAscii
  result.bltinMethods = initTable[string, BltinMethod]()
  result.hasDict = hasDict
  bltinTypes.add(result)


# todo: make it an object with type
type 
  PyNone = ref object of PyObject


method `$`*(obj: PyNone): string =
  "None"

let pyNone* = new PyNone
