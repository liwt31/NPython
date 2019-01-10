import strutils
import algorithm

import pyobject
import baseBundle
import tupleobject
import exceptions

export exceptions

macro genMethodMacros: untyped  =
  result = newStmtList()
  for i in ExceptionToken.low..ExceptionToken.high:
    let objName = $ExceptionToken(i) & "Error"
    result.add(getAst(methodMacroTmpl(ident(objname), objname, 
      newLit(false), newLit(false))))


genMethodMacros


template newMagicTmpl(excpName: untyped, excpNameStr: string) = 

  `impl excpName ErrorUnary` repr:
    # must return pyStringObject, used when formatting traceback
    var msg: string
    if self.msg.isNil:
      msg = "" # could be improved
    elif self.msg.ofPyStrObject:
      msg = PyStrObject(self.msg).str
    else:
      # ensure this is either an throwned exception or string for user-defined type
      let msgObj = self.msg.callmagic(repr)
      if msgObj.isThrownException:
        msg = "evaluating __repr__ failed"
      else:
        msg = PyStrObject(msgObj).str
    let str = $self.tk & "Error: " & msg
    newPyString(str)

  # this is for initialization at Python level
  proc `newPy excpName Error`(tp: PyObject, args:seq[PyObject]): PyObject {. cdecl .} = 
    let excp = `newPy excpName ErrorSimple`()
    excp.tk = ExceptionToken.`excpName`
    excp.msg = newPyTuple(args) 
    excp
  `py excpName ErrorObjectType`.magicMethods.new = `newPy excpName Error`



macro genNewMagic: untyped = 
  result = newStmtList()
  for i in ExceptionToken.low..ExceptionToken.high:
    let tokenStr = $ExceptionToken(i)
    result.add(getAst(newMagicTmpl(ident(tokenStr), tokenStr & "Error")))


genNewMagic()


proc excpStrWithContext*(excp: PyExceptionObject):string = 
  var cur = excp
  var excpStrs: seq[string]
  while not cur.isNil:
    excpStrs.add PyStrObject(reprPyBaseErrorObject(cur)).str
    cur = cur.context
  let joinMsg = "\nDuring handling of the above exception, another exception occured\n"
  excpStrs.reversed.join(joinMsg)
  

proc matchExcp*(target: PyTypeObject, current: PyExceptionObject): PyBoolObject = 
  var tp = current.pyType
  while tp != nil:
    if tp == target:
      return pyTrueObj
    tp = tp.base
  pyFalseObj


proc isExceptionType*(obj: PyObject): bool = 
  if not (obj.pyType.tp == PyTypeToken.Type):
    return false
  let objType = PyTypeObject(obj)
  objType.tp == PyTypeToken.BaseError

when isMainModule:
  let excp = pyNameErrorObjectType.magicMethods.new(pyNameErrorObjectType, @[])
  echo PyNameErrorObject(excp).tk
