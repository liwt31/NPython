import os
import algorithm
import strformat

import compile

import opcode
import bltinmodule
import ../Objects/[pyobject, frameobject, stringobject,
  codeobject, dictobject, methodobject, exceptions, boolobject,
  funcobject]


template doBinary(opName: untyped) =
  let op2 = f.pop
  let op1 = f.pop
  let res = op1.call(opName, op2)
  f.push(res)


proc evalFrame*(f: PyFrameObject): (PyObject, PyExceptionObject) = 
  var retObj: PyObject
  var retExpt: PyExceptionObject
  while not f.exhausted:
    var (opCode, opArg) = f.nextInstr
    case opCode
    of OpCode.PopTop:
      discard f.pop

    of OpCode.UnaryNegative:
      let top = f.pop
      f.push top.call(negative)

    of OpCode.BinaryPower:
      doBinary(power)

    of OpCode.BinaryMultiply:
      doBinary(multiply)

    of OpCode.BinaryModulo:
      doBinary(remainder)

    of OpCode.BinaryAdd:
      doBinary(add)

    of OpCode.BinarySubtract:
      doBinary(subtract)

    of OpCode.BinaryFloorDivide:
      doBinary(floorDivide)

    of OpCode.BinaryTrueDivide:
      doBinary(trueDivide)

    of OpCode.PrintExpr:
      let top = f.pop
      if top != pyNone:
        var (retObj, retExcpt) = builtinPrint(@[top])
        # todo: error handling
      
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
      elif f.builtins.hasKey(name):
        obj = f.builtins[name]
      else:
        assert false
      f.push(obj)

    of OpCode.CompareOp:
      let cmpOp = CmpOp(opArg)
      case cmpOp
      of CmpOp.Lt:
        doBinary(lt)
      of CmpOp.Eq:
        doBinary(eq)
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

    of OpCode.LoadFast:
      f.push f.fastLocals[opArg]

    of OpCode.StoreFast:
      f.fastLocals[opArg] = f.pop

    of OpCode.CallFunction:
      var args: seq[PyObject]
      for i in 0..<opArg:
        args.add f.pop
      args = args.reversed
      let funcObj = f.pop
      var 
        ret: PyObject
        err: PyExceptionObject
      if funcObj of PyBltinFuncObject:
        (ret, err) = PyBltinFuncObject(funcObj).call(args)
      elif funcObj of PyFunctionObject:
        let newF = newPyFrame(PyFunctionObject(funcObj).code, args, f)
        (ret, err) = newF.evalFrame
      else:
        assert false
      f.push ret

    of OpCode.MakeFunction:
      assert opArg == 0
      let name = f.pop
      assert name of PyStringObject
      let code = f.pop
      assert code of PyCodeObject
      f.push newPyFunction(PyStringObject(name), PyCodeObject(code))

    else:
      echo fmt"!!! NOT IMPLEMENTED OPCODE {opCode} IN EVAL FRAME !!!"

  result = (retObj, retExpt)


proc runCode*(co: PyCodeObject) = 
  when defined(debug):
    echo co
  let f = newPyFrame(co, @[], nil)
  var (retObj, retExp) = f.evalFrame


proc runString*(input: TaintedString) = 
  let co = compile(input)
  runCode(co)


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  input.runString

