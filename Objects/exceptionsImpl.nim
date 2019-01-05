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

  `impl excpName ErrorUnary` str:
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


when isMainModule:
  let excp = pyNameErrorObjectType.magicMethods.new(pyNameErrorObjectType, @[])
  echo PyNameErrorObject(excp).tk
