import pyobject


type
  PySeqIterObject* = ref object of PyObject
    items: seq[PyObject]
    idx: int


let pySeqIterObjectType* = newPyType("sequence-iterator")

proc iterNextFunc(selfNoCast: PyObject): PyObject =
  let self = PySeqIterObject(selfNoCast)
  if self.idx == self.items.len:
    return newStopIterError()
  result = self.items[self.idx]
  inc self.idx

pySeqIterObjectType.iternext = iterNextFunc

proc newPySeqIter*(items: seq[PyObject]): PySeqIterObject = 
  new result
  result.items = items
  result.pyType = pySeqIterObjectType
  
