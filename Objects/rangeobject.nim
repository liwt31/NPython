import strformat

import bigints

import pyobject
import numobjects
import boolobject
import stringobject


declarePyType Range():
  start: PyIntObject
  ending: PyIntObject
  step: PyIntObject
  length: PyIntObject

implRangeUnary repr:
  # todo: make it the same as CPython
  newPyString(fmt"range({self.start.v}, {self.ending.v}, {self.step.v}, {self.length.v})")

implRangeUnary str:
  self.reprPyRangeObject
  

proc newRange(theType: PyObject, args:seq[PyObject]): PyObject = 
  for arg in args:
    if not (arg of PyIntObject):
      # CPython uses duck typing here, anything behaves like an int
      # can be passed as argument. Too early for NPython to consider
      # this.
      return newTypeError("range() only support int arguments")
  var start, ending, step: PyIntObject
  case args.len
  of 1:
    start = newPyInt(0)
    ending = PyIntObject(args[0])
    step = newPyInt(1)
  of 2:
    start = PyIntObject(args[0])
    ending = PyIntObject(args[1])
    step = newPyInt(1)
  of 3:
    start = PyIntObject(args[0])
    ending = PyIntObject(args[1])
    if step.v == 0:
      return newValueError("range() step must not be 0")
    step = PyIntObject(args[2])
  else:
    return newTypeError("range() expected 1-3 arguments")
  # range(0, 2, 3): l = 1
  # range(0, 3, 3): l = 1
  # range(0, 3, 4): l = 2
  var length = (ending.v - start.v + step.v - 1) div step.v
  if length < 0:
    length = initBigInt(0)
  let newPyRange = newPyRangeSimple()
  newPyRange.start = start
  newPyRange.ending = ending
  newPyRange.step = step
  newPyRange.length = newPyInt(length)
  newPyRange


pyRangeObjectType.magicMethods.new = newRange


declarePyType RangeIter():
  start: PyIntObject
  step: PyIntObject
  length: PyIntObject
  index: PyIntObject


proc iterRange(selfNoCast: PyObject): 
  PyObject {. castSelf: PyRangeObject .} = 
  let iter = newPyRangeIterSimple()
  iter.start = self.start
  iter.step = self.step
  iter.length = self.length
  iter.index = newPyInt(0)
  iter


proc nextRangeIter(selfNoCast: PyObject):
  PyObject {. castSelf: PyRangeIterObject .} = 
  if self.index.callMagic(lt, self.length) == pyTrueObj:
    result = newPyInt(self.start.v + self.index.v * self.step.v)
    let newIndex = self.index.callMagic(add, newPyInt(1))
    self.index = PyIntObject(newIndex)
  else:
    return newStopIterError()


pyRangeObjectType.magicMethods.iter = iterRange
pyRangeIterObjectType.magicMethods.iternext = nextRangeIter
