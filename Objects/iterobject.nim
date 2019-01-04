import pyobject
import exceptions


declarePyType SeqIter():
    items: seq[PyObject]
    idx: int

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
  
