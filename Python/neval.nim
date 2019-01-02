import os
import macros except name
import algorithm
import strformat
import tables

import compile

import opcode
import coreconfig
import bltinmodule
import ../Objects/[pyobject, typeobject, frameobject, stringobject,
  codeobject, dictobject, methodobject, boolobject, listobject,
  funcobject, moduleobject, iterobject]
import ../Utils/utils

proc pyImport*(name: PyStrObject): PyObject
proc newPyFrame*(fun: PyFunctionObject, 
                 args: seq[PyObject], 
                 back: PyFrameObject): PyFrameObject

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
  # in future, should get rid of the abstraction of seq and use a dynamically
  # create buffer directly
  #[
  var opCodes = newSeq[OpCode](f.code.len)
  var opArgs = newSeq[int](f.code.len)
  for idx, instrTuple in f.code.code:
    opCodes[idx] = instrTuple[0]
    opArgs[idx] = instrTuple[1]
  ]#

  let opCodes = cast[int](createU(OpCode, f.code.len))
  let opArgs = cast[int](createU(int, f.code.len))
  for idx, instrTuple in f.code.code:
    cast[ptr OpCode](opCodes + idx * sizeof(OpCode))[] = instrTuple[0]
    cast[ptr int](opArgs + idx * sizeof(int))[] = instrTuple[1]


  var lastI = -1

  # instruction helpers
  var opCode: OpCode
  var opArg: int
  template fetchInstr = 
    inc lastI
    opCode = cast[ptr OpCode](opCodes + lastI * sizeof(OpCode))[]
    opArg = cast[ptr int](opArgs + lastI * sizeof(int))[]

  template jumpTo(i: int) = 
    lastI = i - 1

   
  # todo: determine max stackSz at compile time
  # mixing GCed and not GCed objects is dangerous in Nim, so here
  # we treat pointers as ints and do completely manual management.
  # `GCref()` and `GCunref` very time consuming,
  # far from something like `inc refCount`, contains loop...
  var stackSz = 32
  var valStack = cast[int](createU(int, stackSz))
  var sIdx = -1

  # retain these templates for future optimization
  template sTop: PyObject = 
    cast[PyObject](cast[ptr int](valStack + sIdx * sizeof(int))[])

  template sPop: PyObject = 
    let top = sTop()
    dec sIdx
    GCunref(top)
    top

  template sSetTop(obj: PyObject) = 
    let topPtr = cast[ptr int](valStack + sIdx * sizeof(int)) 
    GCunref(cast[PyObject](topPtr[]))
    topPtr[] = cast[int](obj[].addr)
    GCref(obj)

  template sPush(obj: PyObject) = 
    inc sIdx
    GCref(obj)
    if sIdx == stackSz:
      stackSz *= 2
      valStack = cast[int](realloc(cast[ptr int](valStack), stackSz * sizeof(int)))

    cast[ptr int](valStack + sIdx * sizeof(int))[] = cast[int](obj[].addr)

  template cleanUp = 
    while sIdx != -1:
      discard sPop
    dealloc(cast[ptr OpCode](opCodes))
    dealloc(cast[ptr int](opArgs))
    dealloc(cast[ptr int](valStack))

  # local cache
  let constants = f.code.constants
  let names = f.code.names
  var fastLocals = f.fastLocals

  # the main interpreter loop
  while true:
    fetchInstr
    when defined(debug):
      echo opCode
    case opCode
    of OpCode.PopTop:
      discard sPop

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
      let iterObj = checkIterable(top)
      if iterObj.isThrownException:
        result = iterObj
        break
      sSetTop(iterObj)

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
      unreachable("locals() scope not implemented")
      #[
      let name = f.getname(opArg)
      f.locals[name] = sPop()
      ]#

    of OpCode.ForIter:
      let top = sTop()
      let nextFunc = top.pyType.magicMethods.iternext
      if nextFunc.isNil:
        unreachable
      let retObj = nextFunc(top)
      if retObj.isStopIter:
        discard sPop()
        jumpTo(opArg)
      elif retObj.isThrownException:
        result = retObj
        break
      else:
        sPush retObj

    of OpCode.StoreGlobal:
      let name = names[opArg]
      f.globals[name] = sPop()

    of OpCode.LoadConst:
      sPush(constants[opArg])

    of OpCode.LoadName:
      unreachable("locals() scope not implemented")
      #[
      # todo: hash only once when dict is improved
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
      ]#

    of OpCode.BuildList:
      # this can be done more elegantly with setItem
      var args: seq[PyObject]
      for i in 0..<opArg:
        args.add sPop()
      args = args.reversed
      let newList = newPyList()
      for item in args:
        let retObj = newList.appendPyListObject(@[item])
        if retObj.isThrownException:
          result = retObj
          break
      sPush newList 

    of OpCode.LoadAttr:
      let name = names[opArg]
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

    of OpCode.ImportName:
      let name = names[opArg]
      let retObj = pyImport(name)
      if retObj.isThrownException:
        result = retObj
        break
      sPush retObj

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

    of OpCode.LoadGlobal:
      let name = names[opArg]
      var obj: PyObject
      if f.globals.hasKey(name):
        obj = f.globals[name]
      elif bltinDict.hasKey(name):
        obj = bltinDict[name]
      else:
        result = newNameError(name.str)
        break
      sPush obj

    of OpCode.LoadFast:
      let obj = fastLocals[opArg]
      if obj.isNil:
        let name = f.code.localVars[opArg]
        let msg = fmt"local variable {name} referenced before assignment"
        result = newUnboundLocalError(msg)
        break
      sPush obj

    of OpCode.StoreFast:
      fastLocals[opArg] = sPop()

    of OpCode.CallFunction:
      var args: seq[PyObject]
      for i in 0..<opArg:
        args.add sPop()
      args = args.reversed
      let funcObj = sPop()
      var retObj: PyObject
      # runtime function, evaluate recursively
      if funcObj of PyFunctionObject:
        let newF = newPyFrame(PyFunctionObject(funcObj), args, f)
        retObj = newF.evalFrame
      # else use dispatcher defined in methodobject.nim
      # todo: should first dispatch Nim level function. low priority because
      # profit is unknown
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
      assert name of PyStrObject
      let code = sPop()
      assert code of PyCodeObject
      sPush newPyFunction(PyStrObject(name), PyCodeObject(code), f.globals)

    else:
      let msg = fmt"!!! NOT IMPLEMENTED OPCODE {opCode} IN EVAL FRAME !!!"
      result = newNotImplementedError(msg)
      break

  cleanUp()
  # currently no cleaning should be done, but in future 
  # f.fastLocals = fastLocals could be necessary


proc pyImport*(name: PyStrObject): PyObject =
  let filepath = pyConfig.path.joinPath(name.str).addFileExt("py")
  if not filepath.existsFile:
    return newImportError(fmt"File {filepath} not found")
  let input = readFile(filepath)
  var co: PyCodeObject
  try:
    co = compile(input)
  except SyntaxError:
    let msg = getCurrentExceptionMsg()
    return newImportError(fmt"Syntax Error: {msg}")
  when defined(debug):
    echo co
  let fun = newPyFunction(name, co, newPyDict())
  let f = newPyFrame(fun, @[], nil)
  let retObj = f.evalFrame
  if retObj.isThrownException:
    return retObj
  let module = newPyModule(name)
  module.dict = f.globals
  module

proc newPyFrame*(fun: PyFunctionObject, 
                 args: seq[PyObject], 
                 back: PyFrameObject): PyFrameObject = 
  let code = fun.code
  assert code != nil
  result = new PyFrameObject
  result.back = back
  result.code = code
  result.globals = fun.globals
  # builtins not used for now
  # result.builtins = bltinDict
  result.fastLocals = newSeq[PyObject](code.localVars.len)
  for idx, arg in args:
    result.fastLocals[idx] = arg

proc runCode*(co: PyCodeObject): PyObject = 
  when defined(debug):
    echo co
  let fun = newPyFunction(newPyString("main"), co, newPyDict())
  let f = newPyFrame(fun, @[], nil)
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

