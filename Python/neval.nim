import os
import algorithm
import strformat

import compile

import opcode
import bltinmodule
import ../Objects/[pyobject, frameobject, stringobject,
  codeobject, dictobject, methodobject, exceptions, boolobject,
  funcobject]
import ../Utils/utils


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
    when defined(debug):
      echo opCode
    case opCode
    of OpCode.PopTop:
      discard f.pop

    of OpCode.NOP:
      continue

    of OpCode.UnaryNegative:
      let top = f.pop
      f.push top.call(negative)

    of OpCode.UnaryNot:
      let top = f.pop
      f.push top.call(Not)

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
        retExpt = newNameError(name)
        break
        
      f.push(obj)

    of OpCode.CompareOp:
      let cmpOp = CmpOp(opArg)
      case cmpOp
      of CmpOp.Lt:
        doBinary(lt)
      of CmpOp.Le:
        doBinary(le)
      of CmpOp.Eq:
        doBinary(eq)
      of CmpOp.Ne:
        doBinary(ne)
      of CmpOp.Gt:
        doBinary(gt)
      of CmpOp.Ge:
        doBinary(ge)
      else:
        unreachable  # should be blocked by ast, compiler

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
      if funcObj of PyBltinFuncObject:
        (retObj, retExpt) = PyBltinFuncObject(funcObj).call(args)
      elif funcObj of PyFunctionObject:
        let newF = newPyFrame(PyFunctionObject(funcObj).code, args, f)
        (retObj, retExpt) = newF.evalFrame
      else:
        unreachable
      if retExpt != nil:
        break
      f.push retObj

    of OpCode.MakeFunction:
      assert opArg == 0
      let name = f.pop
      assert name of PyStringObject
      let code = f.pop
      assert code of PyCodeObject
      f.push newPyFunction(PyStringObject(name), PyCodeObject(code))

    else:
      let msg = fmt"!!! NOT IMPLEMENTED OPCODE {opCode} IN EVAL FRAME !!!"
      retExpt = newNotImplementedError(msg)
      break

  result = (retObj, retExpt)


proc runCode*(co: PyCodeObject): (PyObject, PyExceptionObject) = 
  when defined(debug):
    echo co
  let f = newPyFrame(co, @[], nil)
  f.evalFrame


proc runString*(input: TaintedString): (PyObject, PyExceptionObject) = 
  let co = compile(input)
  runCode(co)


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  var (retObj, retExpt) = input.runString
  if retExpt != nil:
    echo retExpt
  else:
    echo retObj

