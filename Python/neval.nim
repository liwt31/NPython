import os
import algorithm
import strformat

import compile

import opcode
import bltinmodule
import ../Objects/[pyobject, typeobject, frameobject, stringobject,
  codeobject, dictobject, methodobject, boolobjectBase,
  funcobject]
import ../Utils/utils


template doUnary(opName: untyped) = 
  let top = f.top
  f.setTop top.callMagic(opName)

template doBinary(opName: untyped) =
  let op2 = f.pop
  let op1 = f.top
  let res = op1.callMagic(opName, op2)
  if res.isThrownException:
    result = res
    break
  f.setTop res

# function call dispatcher

proc evalFrame*(f: PyFrameObject): PyObject = 
  while not f.exhausted:
    var (opCode, opArg) = f.nextInstr
    when defined(debug):
      echo opCode
    case opCode
    of OpCode.PopTop:
      discard f.pop

    of OpCode.NOP:
      continue

    of OpCode.UnaryPositive:
      doUnary(positive)

    of OpCode.UnaryNegative:
      doUnary(negative)

    of OpCode.UnaryNot:
      doUnary(Not)

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
        let retObj = builtinPrint(@[top])
        # todo: error handling
      
    of OpCode.ReturnValue:
      result = f.pop
      break

    of OpCode.StoreName:
      let name = f.getname(opArg)
      f.locals[name] = f.pop

    of OpCode.LoadConst:
      f.push(f.getConst(opArg))

    of OpCode.LoadName:
      let name = f.getName(opArg)
      var obj: PyObject
      if f.locals.hasKey(name):
        obj = f.locals[name]
      elif f.globals.hasKey(name):
        obj = f.globals[name]
      elif f.builtins.hasKey(name):
        obj = f.builtins[name]
      else:
        result = newNameError(name.str)
        break
        
      f.push(obj)

    of OpCode.BuildList:
      var args: seq[PyObject]
      for i in 0..<opArg:
        args.add f.pop
      args = args.reversed
      let retObj = builtinList(args)
      if retObj.isThrownException:
        result = retObj
        break
      else:
        f.push retObj

    of OpCode.LoadAttr:
      let name = f.getName(opArg)
      let obj = f.top
      let retObj = obj.callMagic(getattr, name)
      if retObj.isThrownException:
        result = retObj
        break
      else:
        f.setTop retObj

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

    of OpCode.JumpIfFalseOrPop:
      if f.top.callMagic(bool) == pyFalseObj:
        f.jumpTo(opArg)
      else:
        discard f.pop

    of OpCode.JumpIfTrueOrPop:
      if f.top.callMagic(bool) == pyTrueObj:
        f.jumpTo(opArg)
      else:
        discard f.pop

    of OpCode.JumpForward, OpCode.JumpAbsolute:
      f.jumpTo(opArg)

    of OpCode.PopJumpIfFalse:
      let top = f.pop
      let boolTop = top.callMagic(bool)
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
      var retObj: PyObject
      # runtime function, evaluate recursively
      if funcObj of PyFunctionObject:
        let newF = newPyFrame(PyFunctionObject(funcObj).code, args, f)
        retObj = newF.evalFrame
      # else use dispatcher defined in methodobject.nim
      else:
        retObj = funcObj.call(args)
      if retObj.isThrownException:
        # should handle here, currently simply throw it again
        result = retObj
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
      result = newNotImplementedError(msg)
      break


proc runCode*(co: PyCodeObject): PyObject = 
  when defined(debug):
    echo co
  let f = newPyFrame(co, @[], nil)
  f.evalFrame


proc runString*(input: TaintedString): PyObject = 
  let co = compile(input)
  runCode(co)


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  var retObj = input.runString
  echo retObj

