import strformat

import bigints

import pyobject
import exceptions
import numobjects
import boolobject
import stringobject


declarePyType Range():
  start: PyIntObject
  ending: PyIntObject
  step: PyIntObject
  length: PyIntObject


implRangeUnary len:
  self.length

implRangeUnary repr:
  # todo: make it the same as CPython
  newPyString(fmt"range({self.start.v}, {self.ending.v}, {self.step.v}, {self.length.v})")

implRangeUnary str:
  self.reprPyRangeObject
  

proc newRange(theType: PyObject, args:seq[PyObject]): PyObject {. cdecl .} = 
  for arg in args:
    if not arg.ofPyIntObject:
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
    step = PyIntObject(args[2])
    if step.v == 0:
      return newValueError("range() step must not be 0")
  else:
    return newTypeError("range() expected 1-3 arguments")
  var length: BigInt
  # might need to refine this if duck typing is used
  # range(0, 2, 3): l = 1
  # range(0, 3, 3): l = 1
  # range(0, 3, 4): l = 2
  if 0 < step.v:
    length = (ending.v - start.v + step.v - 1) div step.v
  # range(1, -1, -1): l = 2
  elif step.v < 0:
    length = (-ending.v + start.v - step.v - 1) div -step.v
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


implRangeUnary iter:
  let iter = newPyRangeIterSimple()
  iter.start = self.start
  iter.step = self.step
  iter.length = self.length
  iter.index = newPyInt(0)
  iter



implRangeIterUnary iter:
  self


implRangeIterUnary iternext:
  if self.index.callMagic(lt, self.length) == pyTrueObj:
    result = newPyInt(self.start.v + self.index.v * self.step.v)
    let newIndex = self.index.callMagic(add, newPyInt(1))
    self.index = PyIntObject(newIndex)
  else:
    return newStopIterError()

