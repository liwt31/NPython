import tables


import pyobject
import exceptions


type 
  PyDictObject* = ref object of PyObject
    table: OrderedTable[PyObject, PyObject]

proc newPyDict* : PyDictObject = 
  new result
  result.table = initOrderedTable[PyObject, PyObject]()


proc hasKey*(dict: PyDictObject, key: PyObject): bool = 
  return dict.table.hasKey(key)

proc `[]`*(dict: PyDictObject, key: PyObject): PyObject = 
  return dict.table[key]


proc `[]=`*(dict: PyDictObject, key, value: PyObject) = 
  dict.table.del(key) # nothing happens if key is not there
  dict.table[key] = value


proc combine*(dict1: PyDictObject, dict2: PyDictObject): PyDictObject = 
  result = newPyDict()
  for k, v in dict1.table.pairs:
    result[k] = v
  for k, v in dict2.table.pairs:
    if result.hasKey(k):
      assert false
    result[k] = v

