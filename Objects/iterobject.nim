import pyobject
import exceptions


declarePyType SeqIter():
    items: seq[PyObject]
    idx: int

implSeqIterMagic iter:
  self

implSeqIterMagic iternext:
  if self.idx == self.items.len:
    return newStopIterError()
  result = self.items[self.idx]
  inc self.idx

proc newPySeqIter*(items: seq[PyObject]): PySeqIterObject = 
  result = newPySeqIterSimple()
  result.items = items
