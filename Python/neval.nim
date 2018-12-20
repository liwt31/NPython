import os
import strformat

import compile

import opcode
import Objects/[pyobject, frameobject, stringobject,
  codeobject, dictobject, methodobject, exceptions, boolobject]
import bltinmodule


template doBinary(opName: untyped) =
  let op2 = f.pop
  let op1 = f.pop
  let res = op1.call(opName, op2)
  #let res = op1.pyType.methods.opName(op1, op2)
  f.push(res)


proc pyEvalFrame(f: PyFrameObject): (PyObject, PyExceptionObject) = 
  var retObj: PyObject
  var retExpt: PyExceptionObject
  while not f.exhausted:
    var (opCode, opArg) = f.nextInstr
    case opCode
    of OpCode.PopTop:
      discard f.pop

    of OpCode.BinaryPower:
      doBinary(power)

    of OpCode.BinaryAdd:
      doBinary(add)

    of OpCode.BinarySubtract:
      doBinary(substract)

    of OpCode.ReturnValue:
      retObj = f.pop
      break

    of OpCode.StoreName:
      let name = f.getname(opArg)
      f.locals[name] = f.pop

    of OpCode.LoadConst:
      f.push(f.getConst(opArg))

    of OpCode.LoadName:
      let name = f.getname(opArg)
      var obj: PyObject
      if f.locals.hasKey(name):
        obj = f.locals[name]
      elif f.globals.hasKey(name):
        obj = f.globals[name]
      else:
        assert false
      f.push(obj)

    of OpCode.CompareOp:
      let cmpOp = CmpOp(opArg)
      case cmpOp
      of CmpOp.Lt:
        doBinary(lt)
      else:
        assert false

    of OpCode.JumpForward, OpCode.JumpAbsolute:
      f.jumpTo(opArg)

    of OpCode.PopJumpIfFalse:
      let top = f.pop
      let boolTop = top.call(bool)
      if boolTop == pyTrueObj:
        discard
      else:
        f.jumpTo(opArg)

    of OpCode.CallFunction:
      var args: seq[PyObject]
      for i in 0..<opArg:
        args.add f.pop
      let funcObj = f.pop
      assert funcObj of PyBltinFuncObject
      f.push PyBltinFuncObject(funcObj).call(args)
    else:
      echo fmt"!!! NOT IMPLEMENTED OPCODE {opCode} IN EVAL FRAME !!!"

  result = (retObj, retExpt)

when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  let co = compile(input)
  echo co
  let f = newPyFrame(co)
  f.globals[newPyString("print")] = newPyBltinFuncObject(builtInPrint)

  var (retObj, retExp) = pyEvalFrame(f)
  echo retObj

