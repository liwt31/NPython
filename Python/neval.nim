import os
import macros except name
import algorithm
import strformat

import compile

import opcode
import bltinmodule
import ../Objects/[pyobject, typeobject, frameobject, stringobject,
  codeobject, dictobject, methodobject, boolobject,
  funcobject]
import ../Utils/utils


template doUnary(opName: untyped) = 
  let top = sTop()
  let res = top.callMagic(opName)
  if res.isThrownException:
    result = res
    break
  sSetTop res

template doBinary(opName: untyped) =
  let op2 = sPop()
  let op1 = sTop()
  let res = op1.callMagic(opName, op2)
  if res.isThrownException:
    result = res
    break
  sSetTop res

# function call dispatcher

proc evalFrame*(f: PyFrameObject): PyObject = 
  # instructions are fetched so frequently that we should build a local cache
  # instead of doing tons of dereference
  var opCodes = newSeq[OpCode](f.code.len)
  var opArgs = newSeq[int](f.code.len)
  for idx, instrTuple in f.code.code:
    opCodes[idx] = instrTuple[0]
    opArgs[idx] = instrTuple[1]
  var lastI = f.lastI

  # instruction helpers
  var opCode: OpCode
  var opArg: int
  template fetchInstr = 
    inc lastI
    opCode = opCodes[lastI]
    opArg = opArgs[lastI]

  template jumpTo(i: int) = 
    lastI = i - 1

  # value stack helpers
  var valStack: array[64, PyObject]
  var sptr = -1

  template sTop: PyObject = 
    valStack[sptr]

  template sPop: PyObject = 
    let v = valStack[sptr]
    dec sptr
    v

  template sPush(obj: PyObject) = 
    inc sptr
    valStack[sptr] = obj

  template sSetTop(obj: PyObject) = 
    valStack[sptr] = obj

  # the main interpreter loop
  while true:
    fetchInstr
    when defined(debug):
      echo opCode
    case opCode
    of OpCode.PopTop:
      dec sptr

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

    of OpCode.GetIter:
      let top = sTop()
      if top.pyType.iter == nil:
        result = newTypeError(fmt"{top.pyType.name} object is not iterable")
        break
      sSetTop(top.pyType.iter(top))

    of OpCode.PrintExpr:
      let top = sPop()
      if top != pyNone:
        let retObj = builtinPrint(@[top])
        if retObj.isThrownException:
          result = retObj
          break
      
    of OpCode.ReturnValue:
      result = sPop()
      break

    of OpCode.StoreName:
      let name = f.getname(opArg)
      f.locals[name] = sPop()

    of OpCode.ForIter:
      let top = sTop()
      if top.pyType.iternext != nil:
        result = newTypeError(fmt"iter() returned non-iterator of type top.pyType.name")
      let retObj = top.pyType.iternext(top)
      if retObj.isStopIter:
        discard sPop()
        jumpTo(opArg)
      elif retObj.isThrownException:
        result = retObj
        break
      else:
        sPush retObj

    of OpCode.LoadConst:
      sPush(f.getConst(opArg))

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
        
      sPush obj

    of OpCode.BuildList:
      var args: seq[PyObject]
      for i in 0..<opArg:
        args.add sPop()
      args = args.reversed
      let retObj = builtinList(args)
      if retObj.isThrownException:
        result = retObj
        break
      else:
        sPush retObj

    of OpCode.LoadAttr:
      let name = f.getName(opArg)
      let obj = sTop()
      let retObj = obj.callMagic(getattr, name)
      if retObj.isThrownException:
        result = retObj
        break
      else:
        sSetTop retObj

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
      let top = sTop()
      if top.callMagic(bool) == pyFalseObj:
        jumpTo(opArg)
      else:
        discard sPop()

    of OpCode.JumpIfTrueOrPop:
      let top = sTop()
      if top.callMagic(bool) == pyTrueObj:
        jumpTo(opArg)
      else:
        discard sPop()

    of OpCode.JumpForward, OpCode.JumpAbsolute:
      jumpTo(opArg)

    of OpCode.PopJumpIfFalse:
      let top = sPop()
      let boolTop = top.callMagic(bool)
      if boolTop == pyTrueObj:
        discard
      else:
        jumpTo(opArg)

    of OpCode.LoadFast:
      sPush f.fastLocals[opArg]

    of OpCode.StoreFast:
      f.fastLocals[opArg] = sPop()

    of OpCode.CallFunction:
      var args: seq[PyObject]
      for i in 0..<opArg:
        args.add sPop()
      args = args.reversed
      let funcObj = sPop()
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
      sPush retObj

    of OpCode.MakeFunction:
      assert opArg == 0
      let name = sPop()
      assert name of PyStringObject
      let code = sPop()
      assert code of PyCodeObject
      sPush newPyFunction(PyStringObject(name), PyCodeObject(code))

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

