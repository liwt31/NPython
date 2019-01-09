import os
import macros except name
import algorithm
import strformat
import tables

import compile

import opcode
import coreconfig
import bltinmodule
import ../Objects/bundle
import ../Utils/utils


proc pyImport*(name: PyStrObject): PyObject
proc newPyFrame*(fun: PyFuncObject, 
                 args: seq[PyObject], 
                 back: PyFrameObject): PyFrameObject

template doUnary(opName: untyped) = 
  let top = sTop()
  let res = top.callMagic(opName)
  if res.isThrownException:
    return res
  sSetTop res

template doBinary(opName: untyped) =
  let op2 = sPop()
  let op1 = sTop()
  let res = op1.callMagic(opName, op2)
  if res.isThrownException:
    return res
  sSetTop res

# the same as doBinary, but need to rotate!
template doBinaryContain: PyObject = 
  let op1 = sPop()
  let op2 = sTop()
  let res = op1.callMagic(contains, op2)
  if res.isThrownException:
    return res
  res

template getBoolFast(obj: PyObject): bool = 
  var ret: bool
  if obj.ofPyBoolObject:
    ret = PyBoolObject(obj).b
  # if user defined class tried to return non bool, 
  # the magic method will return an exception
  let boolObj = top.callMagic(bool)
  if boolObj.isThrownException:
    return boolObj
  else:
    ret = PyBoolObject(boolObj).b
  ret

# function call dispatcher

proc evalFrame*(f: PyFrameObject): PyObject = 
  # instructions are fetched so frequently that we should build a local cache
  # instead of doing tons of dereference

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

   
  # in future, should get rid of the abstraction of seq and use a dynamically
  # created buffer directly. This can reduce time cost of the core neval function
  # by 25%
  var valStack: seq[PyObject]

  # retain these templates for future optimization
  template sTop: PyObject = 
    valStack[^1]

  template sPop: PyObject = 
    valStack.pop

  template sSetTop(obj: PyObject) = 
    valStack[^1] = obj

  template sPush(obj: PyObject) = 
    valStack.add obj

  template cleanUp = 
    dealloc(cast[ptr OpCode](opCodes))
    dealloc(cast[ptr int](opArgs))

  # local cache
  let constants = f.code.constants
  let names = f.code.names
  var fastLocals = f.fastLocals


  # exception handler
  template handelException(excp: PyObject) = 
    assert excp.ofPyExceptionObject
    if not f.hasTryBlock:
      return excp
    jumpTo(f.getTryHandler)


  # the main interpreter loop
  try:
    while true:
      fetchInstr
      when defined(debug):
        echo fmt"{opCode}, {opArg}, {valStack.len}"
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

      of OpCode.StoreSubscr:
        let idx = sPop()
        let obj = sPop()
        let value = sPop()
        let retObj = obj.callMagic(setitem, idx, value)
        if retObj.isThrownException:
          handelException(retObj)

      of OpCode.BinaryAdd:
        doBinary(add)

      of OpCode.BinarySubtract:
        doBinary(subtract)

      of OpCode.BinarySubscr:
        doBinary(getitem)

      of OpCode.BinaryFloorDivide:
        doBinary(floorDivide)

      of OpCode.BinaryTrueDivide:
        doBinary(trueDivide)

      of OpCode.GetIter:
        let top = sTop()
        let iterObj = checkIterable(top)
        if iterObj.isThrownException:
          handelException(iterObj)
        sSetTop(iterObj)

      of OpCode.PrintExpr:
        let top = sPop()
        if top.id != pyNone.id:
          let retObj = builtinPrint(@[top])
          if retObj.isThrownException:
            handelException(retObj)
        
      of OpCode.ReturnValue:
        return sPop()

      of OpCode.PopBlock:
        valStack.setlen f.popTryBlock


      of OpCode.StoreName:
        unreachable("locals() scope not implemented")

      of OpCode.ForIter:
        let top = sTop()
        let nextFunc = top.pyType.magicMethods.iternext
        if nextFunc.isNil:
          echo top.pyType.name
          unreachable
        let retObj = nextFunc(top)
        if retObj.isStopIter:
          discard sPop()
          jumpTo(opArg)
        elif retObj.isThrownException:
          handelException(retObj)
        else:
          sPush retObj

      of OpCode.StoreGlobal:
        let name = names[opArg]
        f.globals[name] = sPop()

      of OpCode.LoadConst:
        sPush(constants[opArg])

      of OpCode.LoadName:
        unreachable("locals() scope not implemented")


      of OpCode.BuildTuple:
        var args = newSeq[PyObject](opArg)
        for i in 1..opArg:
          args[^i] = sPop()
        let newTuple = newPyTuple(args)
        sPush newTuple

      of OpCode.BuildList:
        # this can be done more elegantly with setItem
        var args = newSeq[PyObject](opArg)
        for i in 1..opArg:
          args[^i] = sPop()
        let newList = newPyList(args)
        sPush newList 

      of OpCode.BuildMap:
        let d = newPyDict()
        for i in 0..<opArg:
          let key = sPop()
          let value = sPop()
          let retObj = d.setitemPyDictObject(key, value)
          if retObj.isThrownException:
            handelException(retObj)
        sPush d

      of OpCode.LoadAttr:
        let name = names[opArg]
        let obj = sTop()
        let retObj = obj.callMagic(getattr, name)
        if retObj.isThrownException:
          handelException(retObj)
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
        of CmpOp.In:
          sPush doBinaryContain
        of CmpOp.NotIn:
          let obj = doBinaryContain
          if obj.ofPyBoolObject:
            sPush obj.callMagic(Not)
          else:
            let boolObj = obj.callMagic(bool)
            if boolObj.isThrownException:
              handelException(boolObj)
            if not boolObj.ofPyBoolObject:
              unreachable
            sPush boolObj.callMagic(Not)
        else:
          unreachable  # should be blocked by ast, compiler

      of OpCode.ImportName:
        let name = names[opArg]
        let retObj = pyImport(name)
        if retObj.isThrownException:
          handelException(retObj)
        sPush retObj

      of OpCode.JumpIfFalseOrPop:
        let top = sTop()
        if getBoolFast(top) == false:
          jumpTo(opArg)
        else:
          discard sPop()

      of OpCode.JumpIfTrueOrPop:
        let top = sTop()
        if getBoolFast(top) == true:
          jumpTo(opArg)
        else:
          discard sPop()

      of OpCode.JumpForward, OpCode.JumpAbsolute:
        jumpTo(opArg)

      of OpCode.PopJumpIfFalse:
        let top = sPop()
        if getBoolFast(top) == false:
          jumpTo(opArg)

      of OpCode.PopJumpIfTrue:
        let top = sPop()
        if getBoolFast(top) == true:
          jumpTo(opArg)

      of OpCode.LoadGlobal:
        let name = names[opArg]
        var obj: PyObject
        if f.globals.hasKey(name):
          obj = f.globals[name]
        elif bltinDict.hasKey(name):
          obj = bltinDict[name]
        else:
          let msg = fmt"name '{name.str}' is not defined" 
          handelException(newNameError(msg))
        sPush obj

      of OpCode.SetupFinally:
        f.addTryBlock(opCode, opArg, valStack.len)

      of OpCode.LoadFast:
        let obj = fastLocals[opArg]
        if obj.isNil:
          let name = f.code.localVars[opArg]
          let msg = fmt"local variable {name} referenced before assignment"
          let excp = newUnboundLocalError(msg)
          handelException(excp)
        sPush obj

      of OpCode.StoreFast:
        fastLocals[opArg] = sPop()

      of OpCode.RaiseVarargs:
        if opArg != 1:
          unreachable("should be blocked by compiler")
        let obj = sTop()
        var excp: PyObject
        if obj.isClass:
          let newFunc = PyTypeObject(obj).magicMethods.new
          if newFunc.isNil:
            unreachable("__new__ of exceptions should be initialized")
          excp = newFunc(obj, @[])
        else:
          excp = obj
        if not excp.ofPyExceptionObject:
          unreachable
        PyExceptionObject(excp).thrown = true
        handelException(excp)


      of OpCode.CallFunction:
        var args: seq[PyObject]
        for i in 0..<opArg:
          args.add sPop()
        args = args.reversed
        let funcObj = sPop()
        var retObj: PyObject
        # runtime function, evaluate recursively
        if funcObj.ofPyFuncObject:
          let newF = newPyFrame(PyFuncObject(funcObj), args, f)
          retObj = newF.evalFrame
        # else use dispatcher defined in methodobject.nim
        # todo: should first dispatch Nim level function (same as CPython). 
        # this is of low priority because profit is unknown
        else:
          retObj = funcObj.call(args)
        if retObj.isThrownException:
          handelException(retObj)
        sPush retObj

      of OpCode.MakeFunction:
        # other kinds not implemented
        assert opArg == 0
        let name = sPop()
        assert name.ofPyStrObject
        let code = sPop()
        assert code.ofPyCodeObject
        sPush newPyFunc(PyStrObject(name), PyCodeObject(code), f.globals)

      of OpCode.BuildSlice:
        var lower, upper, step: PyObject
        if opArg == 3:
          step = sPop()
        else:
          assert opArg == 2
          step = pyNone
        upper = sPop()
        lower = sTop()
        let slice = newPySlice(lower, upper, step)
        if slice.isThrownException:
          handelException(slice)
        sSetTop slice

      else:
        let msg = fmt"!!! NOT IMPLEMENTED OPCODE {opCode} IN EVAL FRAME !!!"
        return newNotImplementedError(msg) # no need to handle
  finally:
    cleanUp()
    # currently no cleaning should be done, but in future 
    # f.fastLocals = fastLocals could be necessary


proc pyImport*(name: PyStrObject): PyObject =
  let filepath = pyConfig.path.joinPath(name.str).addFileExt("py")
  if not filepath.existsFile:
    let msg = fmt"File {filepath} not found"
    return newImportError(msg)
  let input = readFile(filepath)
  var co: PyCodeObject
  try:
    co = compile(input)
  except SyntaxError:
    let msg1 = getCurrentExceptionMsg()
    let msg2 = "Syntax Error: " & msg1
    return newImportError(msg2)
  when defined(debug):
    echo co
  let fun = newPyFunc(name, co, newPyDict())
  let f = newPyFrame(fun, @[], nil)
  let retObj = f.evalFrame
  if retObj.isThrownException:
    return retObj
  let module = newPyModule(name)
  module.dict = f.globals
  module

proc newPyFrame*(fun: PyFuncObject, 
                 args: seq[PyObject], 
                 back: PyFrameObject): PyFrameObject = 
  let code = fun.code
  assert code != nil
  result = newPyFrame()
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
  let fun = newPyFunc(newPyString("main"), co, newPyDict())
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

