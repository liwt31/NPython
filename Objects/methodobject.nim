import strformat

import pyobject except name
import stringobject

type
  NFunc* {. pure .} = enum
    BltinFunc,  # general function, no self
    # method has a `self` attribute
    UnaryMethod,   # method with 1 arg
    BinaryMethod,  # method with 2 args
    TernaryMethod, # method with 3 args
    BltinMethod,   # method with arbitary args

    # mixing function and method is to some extent unnatural
    # however, this makes function and method call dispatch most efficient

declarePyType NimFunc():
    name: PyStrObject
    self: PyObject  # not set for BltinFunc
    kind: NFunc
    fun: int  # generic function pointer, determined by kind
                  

proc call*(obj: PyObject, args: seq[PyObject]): PyObject = 
  if obj of PyNimFuncObject:
    let f = PyNimFuncObject(obj)
    case f.kind
    of NFunc.BltinFunc:
      return cast[BltinFunc](f.fun)(args)
    of NFunc.UnaryMethod:
      checkArgNum(0)
      return cast[UnaryMethod](f.fun)(f.self)
    of NFunc.BinaryMethod:
      checkArgNum(1)
      return cast[BinaryMethod](f.fun)(f.self, args[0])
    of NFunc.TernaryMethod:
      checkArgNum(2)
      return cast[TernaryMethod](f.fun)(f.self, args[0], args[1])
    of NFunc.BltinMethod:
      return cast[BltinMethod](f.fun)(f.self, args)

  let callFunc = obj.pyType.magicMethods.call
  if callFunc != nil:
    return callFunc(obj, args)
  newTypeError(fmt"{obj.pyType.name} is not callable")


proc newPyNimFunc*(fun: BltinFunc, name: PyStrObject): PyNimFuncObject =
  result = newPyNimFuncSimple()
  result.name = name
  result.kind = NFunc.BltinFunc
  result.fun = cast[int](fun)
  

template newMethodTmpl(funName, FunType) = 
  proc newPyNimFunc*(fun: FunType, name: PyStrObject, self:PyObject): PyNimFuncObject = 
    result = newPyNimFuncSimple()
    result.name = name
    result.kind = NFunc.FunType
    result.fun = cast[int](fun)
    result.self = self


newMethodTmpl(unaryMethod, UnaryMethod)
newMethodTmpl(binaryMethod, BinaryMethod)
newMethodTmpl(ternaryMethod, TernaryMethod)
newMethodTmpl(bltinMethod, BltinMethod)


#[ have to figure out how to define arg list as something like 
#  call(args: seq[PyObject]) in macro
# the same problem with the builtin print function
implNimFuncMethod call, ():
  discard
]#


