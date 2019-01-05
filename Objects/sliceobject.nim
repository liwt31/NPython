import pyobject
import baseBundle


declarePyType Slice(tpToken):
  start: PyObject
  stop: PyObject
  step: PyObject

# typically a slice is created then destroyed, so use a slice cache is very
# effective. However, this makes creating slice object dynamically impossible, so
# not adopted in NPython

proc newPySlice*(start, stop, step: PyObject): PyObject =
  let slice = newPySliceSimple()
  template setAttrTmpl(attr) =
    if attr.ofPyIntObject or attr.ofPyNoneObject:
      slice.attr = attr
    else:
      let indexFun = attr.pyType.magicMethods.index
      if indexFun.isNil:
        let msg = "slice indices must be integers or None or have an __index__ method"
        return newTypeError(msg)
      else:
        slice.attr = indexFun(attr)

  setAttrTmpl(start)
  setAttrTmpl(stop)
  setAttrTmpl(step)
  slice

