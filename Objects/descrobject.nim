import macros except name
import strformat

import pyobject
import stringobject
import methodobject
import ../Utils/utils

type 
  PyDescrObject = ref object of PyObject
    # type for binding
    dType: PyTypeObject

  PyMethodDescrObject = ref object of PyDescrObject
    name: PyStrObject


  PyUnaryFuncDescrObject = ref object of PyMethodDescrObject
    meth: UnaryFunc


  PyBinaryFuncDescrObject = ref object of PyMethodDescrObject
    meth: BinaryFunc


  PyBltinMethDescrObject = ref object of PyMethodDescrObject
    meth: BltinMethod


let pyMethodDescrType = newPyType("method-descriptor")


template implNew = 
  new result
  result.pyType = pyMethodDescrType
  result.dType = t
  result.meth = meth

  result.name = name



proc newPyMethodDescr*(t: PyTypeObject, 
                       meth: UnaryFunc,
                       name: PyStrObject,
                       ): PyUnaryFuncDescrObject = 
  implNew


proc newPyMethodDescr*(t: PyTypeObject, 
                       meth: BinaryFunc,
                       name: PyStrObject,
                       ): PyBinaryFuncDescrObject = 
  implNew


proc newPyMethodDescr*(t: PyTypeObject, 
                       meth: BltinMethod,
                       name: PyStrObject,
                       ): PyBltinMethDescrObject = 
  implNew


# too many dispather here! harmful to performance.
method getMethodDispatch(descr: PyObject, owner: PyObject): PyObject {. base .}=
  unreachable


method getMethodDispatch(descr: PyUnaryFuncDescrObject, owner: PyObject): PyObject = 
  newPyNFunc(descr.meth, descr.name, owner)


method getMethodDispatch(descr: PyBinaryFuncDescrObject, owner: PyObject): PyObject = 
  newPyNFunc(descr.meth, descr.name, owner)


method getMethodDispatch(descr: PyBltinMethDescrObject, owner: PyObject): PyObject = 
  newPyNFunc(descr.meth, descr.name, owner)


proc getMethod(descr: PyObject, owner: PyObject): PyObject = 
  if not (descr of PyMethodDescrObject):
    unreachable
  let mDescr = PyMethodDescrObject(descr)
  if owner.pyType != mDescr.dType:
    let name = mDescr.name
    let t1 = mDescr.dType.name
    let t2 = owner.pyType.name
    let msg = fmt"descriptor {name} requires a {t1} object but received a {t2}"
    return newTypeError(msg)
  descr.getMethodDispatch(owner)


pyMethodDescrType.magicMethods.descrGet = getMethod
