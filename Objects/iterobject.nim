import pyobject


type
  PySeqIterObject* = ref object of PyObject
    items: seq[PyObject]
    idx: int


let pySeqIterObjectType* = newPyType("sequence-iterator")

proc iterNextFunc(selfNoCast: PyObject): PyObject {. cdecl .}=
  let self = PySeqIterObject(selfNoCast)
  if self.idx == self.items.len:
    return newStopIterError()
  result = self.items[self.idx]
  inc self.idx

pySeqIterObjectType.magicMethods.iternext = iterNextFunc

proc newPySeqIter*(items: seq[PyObject]): PySeqIterObject = 
  new result
  result.items = items
  result.pyType = pySeqIterObjectType
  
