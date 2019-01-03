import strformat

import pyobject
import stringobject
import methodobject
import ../Utils/utils

declarePyType MethodDescr():
  name: PyStrObject
  dType: PyTypeObject
  kind: NFunc
  meth: int


template newMethodDescrTmpl(funName, FunType) = 
  proc newPyMethodDescr*(t: PyTypeObject, 
                         meth: FunType,
                         name: PyStrObject,
                         ): PyMethodDescrObject = 
    result = newPyMethodDescrSimple()
    result.dType = t
    result.kind = NFunc.FunType
    assert result.kind != NFunc.BltinFunc
    result.meth = cast[int](meth)
    result.name = name


newMethodDescrTmpl(unaryMethod, UnaryMethod)
newMethodDescrTmpl(binaryMethod, BinaryMethod)
newMethodDescrTmpl(ternaryMethod, TernaryMethod)
newMethodDescrTmpl(bltinMethod, BltinMethod)


proc getMethod(selfNoCast: PyObject, owner: PyObject): 
  PyObject {. castSelf: PyMethodDescrObject, cdecl .} = 
  if owner.pyType != self.dType:
    let name = self.name
    let t1 = self.dType.name
    let t2 = owner.pyType.name
    let msg = fmt"descriptor {name} requires a {t1} object but received a {t2}"
    return newTypeError(msg)
  case self.kind
  of NFunc.UnaryMethod:
    return newPyNimFunc(cast[UnaryMethod](self.meth), self.name, owner)
  of NFunc.BinaryMethod:
    return newPyNimFunc(cast[BinaryMethod](self.meth), self.name, owner)
  of NFunc.TernaryMethod:
    return newPyNimFunc(cast[TernaryMethod](self.meth), self.name, owner)
  of NFunc.BltinMethod:
    return newPyNimFunc(cast[BltinMethod](self.meth), self.name, owner)
  else:
    unreachable


pyMethodDescrObjectType.magicMethods.get = getMethod
#
#[ have to figure out how to define arg list as something like 
#  call(owner: PyObject, args: seq[PyObject]) in macro
# the same problem with the builtin print function
implNimFuncMethod call, ():
  discard
]#
