import tables


import pyobject
import exceptions


type 
  PyDictObject* = ref object of PyObject
    table: OrderedTable[PyObject, PyObject]

proc newPyDict* : PyDictObject = 
  result = new PyDictObject
  result.table = initOrderedTable[PyObject, PyObject]()


proc hasKey*(dict: PyDictObject, key: PyObject): bool = 
  return dict.table.hasKey(key)

proc `[]`*(dict: PyDictObject, key: PyObject): PyObject = 
  return dict.table[key]


proc `[]=`*(dict: PyDictObject, key, value: PyObject) = 
  dict.table.del(key) # nothing happens if key is not there
  dict.table[key] = value

