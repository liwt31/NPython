import os
import algorithm
import strformat
import tables

import compile
import symtable
import opcode
import coreconfig
import ../Objects/bundle
import ../Utils/utils

# forward declarations to resolve cyclic dependency. Certain function related objects
# have `call` magics that rely on them
proc newPyFrame*(fun: PyFunctionObject): PyFrameObject 
proc newPyFrame*(fun: PyFunctionObject, 
                 args: seq[PyObject], 
                 back: PyFrameObject): PyObject
proc evalFrame*(f: PyFrameObject): PyObject

import ../Objects/typeobject
import bltinmodule

type
  # the exception model is different from CPython. todo: Need more documentation
  # when the model is finished
  #
  # States of the tryblock, currently only Try(default) and Except is used
  TryStatus {. pure .} = enum
    Try,
    Except,
    Else,
    Finally

  TryBlock = ref object
    status: TryStatus
    handler: int
    sPtr: int
    context: PyExceptionObject
    

proc pyImport*(name: PyStrObject): PyObject

template doUnary(opName: untyped) = 
  let top = sTop()
  let res = top.callMagic(opName, handleExcp=true)
  if res.isThrownException:
    handleException(res)
  sSetTop res

template doBinary(opName: untyped) =
  let op2 = sPop()
  let op1 = sTop()
  let res = op1.callMagic(opName, op2, handleExcp=true)
  if res.isThrownException:
    handleException(res)
  sSetTop res

# the same as doBinary, but need to rotate!
template doBinaryContain: PyObject = 
  let op1 = sPop()
  let op2 = sTop()
  let res = op1.callMagic(contains, op2, handleExcp=true)
  if res.isThrownException:
    handleException(res)
  res

# "fast" because check of it's a bool object first and save the callMagic(bool)
template getBoolFast(obj: PyObject): bool = 
  var ret: bool
  if obj.ofPyBoolObject:
    ret = PyBoolObject(obj).b
  # if user defined class tried to return non bool, 
  # the magic method will return an exception
  let boolObj = top.callMagic(bool)
  if boolObj.isThrownException:
    handleException(boolObj)
  else:
    ret = PyBoolObject(boolObj).b
  ret

proc evalFrame*(f: PyFrameObject): PyObject = 
  # instructions are fetched so frequently that we should build a local cache
  # instead of doing tons of dereference

  let opCodes = f.code.opCodes
  let opArgs = f.code.opArgs

  var lastI = -1

  # instruction helpers
  var opCode: OpCode
  var opArg: int
  template fetchInstr: (OpCode, int) = 
    inc lastI
    opCode = opCodes[lastI]
    opArg = opArgs[lastI]
    (opCode, opArg)
    # the silly way
    # f.code.code[lastI]

  template jumpTo(i: int) = 
    lastI = i - 1

  proc setTraceBack(excp: PyExceptionObject) = 
    let lineNo = f.code.lineNos[lastI]
    # for exceptions happened when evaluating the frame no colNo is set
    excp.traceBacks.add (f.code.fileName, f.code.codeName, lineNo, -1)
   
  # in future, should get rid of the abstraction of seq and use a dynamically
  # created buffer directly. This can reduce time cost of the core neval function
  # by 25%
  var valStack: seq[PyObject]

  # retain these templates for future optimization
  template sTop: PyObject = 
    valStack[^1]

  template sPop: PyObject = 
    valStack.pop

  template sPeek(idx: int): PyObject = 
    valStack[^idx]

  template sSetTop(obj: PyObject) = 
    valStack[^1] = obj

  template sPush(obj: PyObject) = 
    valStack.add obj

  template sEmpty: bool = 
    valStack.len == 0

  template sLen: int = 
    valStack.len

  template setStackLen(s: int) = 
    valStack.setlen(s)

  template cleanUp = 
    discard


  # avoid dereference
  let constants = f.code.constants.addr
  let names = f.code.names.addr
  let fastLocals = f.fastLocals.addr
  let cellVars = f.cellVars.addr

  # in CPython this is a finite (20, CO_MAXBLOCKS) sized array as a member of 
  # frameobject. Safety is ensured by the compiler
  var blockStack: seq[TryBlock]

  template hasTryBlock: bool = 
    0 < blockStack.len

  template getTryHandler: int = 
    blockStack[^1].handler
    

  template addTryBlock(opArg, stackPtr: int, cxt:PyExceptionObject=nil) = 
    blockStack.add(TryBlock(handler:opArg, sPtr:stackPtr, context:cxt))

  template getTopBlock: TryBlock = 
    blockStack[^1]

  template popTryBlock: int = 
    let ret = blockStack[^1].sPtr
    discard blockStack.pop
    ret

  template handleException(excp: PyObject) = 
    excpObj = excp
    break

  # the main interpreter loop
  try:
    # exception handler loop
    while true:
      var excpObj: PyObject
      # normal execution loop
      while true:
        {. computedGoto .}
        let (opCode, opArg) = fetchInstr
        when defined(debug):
          echo fmt"{opCode}, {opArg}, {valStack.len}"
        case opCode
        of OpCode.PopTop:
          discard sPop

        of OpCode.DupTop:
          sPush sTop()

        of OpCode.NOP:
          continue

        of OpCode.UnaryPositive:
          doUnary(positive)

        of OpCode.UnaryNegative:
          doUnary(negative)

        of OpCode.UnaryNot:
          doUnary(Not)

        of OpCode.BinaryPower:
          doBinary(pow)

        of OpCode.BinaryMultiply:
          doBinary(mul)

        of OpCode.BinaryModulo:
          doBinary(Mod)

        of OpCode.StoreSubscr:
          let idx = sPop()
          let obj = sPop()
          let value = sPop()
          let retObj = obj.callMagic(setitem, idx, value)
          if retObj.isThrownException:
            handleException(retObj)

        of OpCode.BinaryAdd:
          doBinary(add)

        of OpCode.BinarySubtract:
          doBinary(sub)

        of OpCode.BinarySubscr:
          doBinary(getitem)

        of OpCode.BinaryFloorDivide:
          doBinary(floorDiv)

        of OpCode.BinaryTrueDivide:
          doBinary(trueDiv)

        of OpCode.GetIter:
          let top = sTop()
          let iterObj = getIterableWithCheck(top)
          if iterObj.isThrownException:
            handleException(iterObj)
          sSetTop(iterObj)

        of OpCode.PrintExpr:
          let top = sPop()
          if top.id != pyNone.id:
            # all object should have a repr method properly initialized in typeobject.nim
            let reprObj = top.pyType.magicMethods.repr(top)
            if reprObj.isThrownException:
              handleException(reprObj)

            let retObj = builtinPrint(@[reprObj])
            if retObj.isThrownException:
              handleException(retObj)

        of OpCode.LoadBuildClass:
          sPush bltinDict[newPyStr("__build_class__")]
          
        of OpCode.ReturnValue:
          return sPop()

        of OpCode.PopBlock:
          if sEmpty:
            # no need to reset stack because it's already empty
            discard popTryBlock
          else:
            let top = sTop()
            setStackLen popTryBlock
            # previous `except` clause failed to handle the exception
            if top.isThrownException:
              handleException(top)


        of OpCode.StoreName:
          unreachable("locals() scope not implemented")

        of OpCode.UnpackSequence:
          template inCompatibleLengthError(gotLen: int) = 
            let got {. inject .} = $gotLen
            let msg = fmt"not enough values to unpack (expected {oparg}, got {got})"
            let excp = newValueError(msg)
            handleException(excp)
          let s = sPop()
          if s.ofPyTupleObject():
            let t = PyTupleObject(s)
            if opArg != t.items.len:
              inCompatibleLengthError(t.items.len)
            for i in 1..opArg: 
              sPush t.items[^i]
          elif s.ofPyListObject():
            let l = PyListObject(s)
            if opArg != l.items.len:
              inCompatibleLengthError(l.items.len)
            for i in 1..opArg: 
              sPush l.items[^i]
          else:
            let iterable = getIterableWithCheck(s)
            if iterable.isThrownException:
              handleException(iterable)
            let nextFunc = iterable.getMagic(iternext)
            # there is a much clever approach in CPython
            # the power of low level memory accessing!
            var items = newseq[PyObject](opArg)
            for i in 0..<opArg:
              let retObj = iterable.nextFunc
              if retObj.isStopIter:
                inCompatibleLengthError(i)
              elif retObj.isThrownException:
                handleException(retObj)
              else:
                items[i] = retObj
            for i in 1..opArg: 
              sPush items[^i]

        of OpCode.ForIter:
          let top = sTop()
          let nextFunc = top.getMagic(iternext)
          if nextFunc.isNil:
            echo top.pyType.name
            unreachable
          let retObj = nextFunc(top)
          if retObj.isStopIter:
            discard sPop()
            jumpTo(opArg)
          elif retObj.isThrownException:
            handleException(retObj)
          else:
            sPush retObj

        of OpCode.StoreAttr:
          let name = names[opArg]
          let owner = sPop()
          let v = sPop()
          let retObj = owner.callMagic(setattr, name, v)
          if retObj.isThrownException:
            handleException(retObj)

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
          var args = newSeq[PyObject](opArg)
          for i in 1..opArg:
            args[^i] = sPop()
          # an optimization can save the copy
          let newList = newPyList(args)
          sPush newList 

        of OpCode.BuildMap:
          let d = newPyDict()
          for i in 0..<opArg:
            let key = sPop()
            let value = sPop()
            let retObj = tpMagic(Dict, setitem)(d, key, value)
            if retObj.isThrownException:
              handleException(retObj)
          sPush d

        of OpCode.LoadAttr:
          let name = names[opArg]
          let obj = sTop()
          let retObj = obj.callMagic(getattr, name)
          if retObj.isThrownException:
            handleException(retObj)
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
                handleException(boolObj)
              if not boolObj.ofPyBoolObject:
                unreachable
              sPush boolObj.callMagic(Not)
          of CmpOp.ExcpMatch:
            let targetExcp = sPop()
            if not targetExcp.isExceptionType:
              let msg = "catching classes that do not inherit " & 
                        "from BaseException is not allowed"
              handleException(newTypeError(msg))
            let currentExcp = PyExceptionObject(sTop())
            sPush matchExcp(PyTypeObject(targetExcp), currentExcp)
          else:
            unreachable  # should be blocked by ast, compiler

        of OpCode.ImportName:
          let name = names[opArg]
          let retObj = pyImport(name)
          if retObj.isThrownException:
            handleException(retObj)
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
            handleException(newNameError(msg))
          sPush obj

        of OpCode.SetupFinally:
          if hasTryBlock():
            addTryBlock(opArg, valStack.len, getTopBlock().context)
          else:
            addTryBlock(opArg, valStack.len, nil)

        of OpCode.LoadFast:
          let obj = fastLocals[opArg]
          if obj.isNil:
            let name = f.code.localVars[opArg]
            let msg = fmt"local variable {name} referenced before assignment"
            let excp = newUnboundLocalError(msg)
            handleException(excp)
          sPush obj

        of OpCode.StoreFast:
          fastLocals[opArg] = sPop()

        of OpCode.RaiseVarargs:
          case opArg
          of 0:
            if (not hasTryBlock) or getTopBlock.context.isNil:
              let excp = newRunTimeError("No active exception to reraise")
              handleException(excp)
            else:
              handleException(getTopBlock.context)
          of 1:
            let obj = sPop()
            var excp: PyObject
            if obj.isClass:
              let newFunc = PyTypeObject(obj).magicMethods.New
              if newFunc.isNil:
                unreachable("__new__ of exceptions should be initialized")
              excp = newFunc(@[])
            else:
              excp = obj
            if not excp.ofPyExceptionObject:
              unreachable
            PyExceptionObject(excp).thrown = true
            handleException(excp)
          else:
            unreachable(fmt"RaiseVarargs has opArg {opArg}")

        of OpCode.CallFunction:
          var args = newseq[PyObject](opArg)
          for i in 1..opArg:
            args[^i] = sPop()
          let funcObjNoCast = sPop()
          var retObj: PyObject
          # runtime function, evaluate recursively
          if funcObjNoCast.ofPyFunctionObject:
            let funcObj = PyFunctionObject(funcObjNoCast)
            # may fail because of wrong number of args, etc.
            let newF = newPyFrame(funcObj, args, f)
            if newF.isThrownException:
              handleException(newF)
            retObj = PyFrameObject(newF).evalFrame
          # todo: should first dispatch Nim level function (same as CPython). 
          # this is of low priority because profit is unknown
          else:
            let callFunc = funcObjNoCast.pyType.magicMethods.call
            if callFunc.isNil:
              let msg = fmt"{funcObjNoCast.pyType.name} is not callable"
              retObj = newTypeError(msg)
            else:
              retObj = callFunc(funcObjNoCast, args)
          if retObj.isThrownException:
            handleException(retObj)
          sPush retObj

        of OpCode.MakeFunction:
          # other kinds not implemented
          assert opArg == 0 or opArg == 8
          let name = sPop()
          let code = sPop()
          var closure: PyObject
          if (opArg and 8) != 0:
            closure = sPop()
          sPush newPyFunc(PyStrObject(name), PyCodeObject(code), f.globals, closure)

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
            handleException(slice)
          sSetTop slice

        of OpCode.LoadClosure:
          sPush cellVars[opArg]

        of OpCode.LoadDeref:
          let c = cellVars[opArg]
          if c.refObj.isNil:
            let name = f.code.cellVars[opArg]
            let msg = fmt"local variable {name} referenced before assignment"
            let excp = newUnboundLocalError(msg)
            handleException(excp)
          sPush c.refObj

        of OpCode.StoreDeref:
          cellVars[opArg].refObj = sPop

        of OpCode.ListAppend:
          let top = sPop()
          let l = sPeek(opArg)
          assert l.ofPyListObject
          PyListObject(l).items.add top

        else:
          let msg = fmt"!!! NOT IMPLEMENTED OPCODE {opCode} IN EVAL FRAME !!!"
          return newNotImplementedError(msg) # no need to handle

      # exception handler, return exception or re-enter the loop with new instruction index
      block exceptionHandler:
        assert (not excpObj.isNil)
        assert excpObj.ofPyExceptionObject
        let excp = PyExceptionObject(excpObj)
        excp.setTraceBack
        while hasTryBlock():
          let topBlock = getTopBlock()
          case topBlock.status
          of TryStatus.Try: # error occured in `try` suite
            excp.context = topBlock.context
            topBlock.context = excp
            topBlock.status = TryStatus.Except
            setStackLen topBlock.sPtr
            sPush excp # for comparison in `except` clause
            jumpTo(topBlock.handler)
            when defined(debug):
              echo fmt"handling exception, jump to {topBlock.handler}"
            break exceptionHandler # continue normal execution
          of TryStatus.Except: # error occured in `except` suite
            if excp.context.isNil: # raised without nesting try/except
              excp.context = topBlock.context 
            # else with nesting try/except, the context has already been set properly
            setStackLen popTryBlock() # try to find a handler along the stack
          else:
            unreachable
        return excp
  finally:
    cleanUp()


proc pyImport*(name: PyStrObject): PyObject =
  let filepath = pyConfig.path.joinPath(name.str).addFileExt("py")
  if not filepath.existsFile:
    let msg = fmt"File {filepath} not found"
    return newImportError(msg)
  let input = readFile(filepath)
  let compileRes = compile(input, filepath)
  if compileRes.isThrownException:
    return compileRes

  let co = PyCodeObject(compileRes)

  when defined(debug):
    echo co
  let fun = newPyFunc(name, co, newPyDict())
  let f = newPyFrame(fun)
  let retObj = f.evalFrame
  if retObj.isThrownException:
    return retObj
  let module = newPyModule(name)
  module.dict = f.globals
  module

proc newPyFrame*(fun: PyFunctionObject): PyFrameObject = 
  let obj = newPyFrame(fun, @[], nil)
  if obj.isThrownException:
    unreachable
  else:
    return PyFrameObject(obj)

proc newPyFrame*(fun: PyFunctionObject, 
                 args: seq[PyObject], 
                 back: PyFrameObject): PyObject = 
  let code = fun.code
  # handle wrong number of args
  if code.argScopes.len < args.len:
    let msg = fmt"{fun.name.str}() takes {code.argScopes.len} positional arguments but {args.len} were given"
    return newTypeError(msg)
  elif args.len < code.argScopes.len:
    let diff = code.argScopes.len - args.len
    let msg = fmt"{fun.name.str}() missing {diff} required positional argument: " & 
              fmt"{code.argNames[^diff..^1]}. {args.len} args are given."
    return newTypeError(msg)
  let frame = newPyFrame()
  frame.back = back
  frame.code = code
  frame.globals = fun.globals
  # todo: use flags for faster simple function call
  frame.fastLocals = newSeq[PyObject](code.localVars.len)
  frame.cellVars = newSeq[PyCellObject](code.cellVars.len + code.freeVars.len)
  # init cells. Can do some optimizations here
  for i in 0..<code.cellVars.len:
    frame.cellVars[i] = newPyCell(nil)
  # setup arguments
  for i in 0..<args.len:
    let (scope, scopeIdx) = code.argScopes[i]
    case scope
    of Scope.Local:
      frame.fastLocals[scopeIdx] = args[i]
    of Scope.Global:
      unreachable
    of Scope.Cell:
      frame.cellVars[scopeIdx].refObj = args[i]
    of Scope.Free:
      unreachable("arguments can't be free")
  # setup closures. Note some are done when setting up arguments
  if fun.closure.isNil:
    assert code.freeVars.len == 0
  else:
    assert code.freevars.len == fun.closure.items.len
    for idx, c in fun.closure.items:
      assert c.ofPyCellObject
      frame.cellVars[code.cellVars.len + idx] = PyCellObject(c)
  frame


implBltinFunc buildClass(funcObj: PyFunctionObject, name: PyStrObject), "__build_class__":
  # may fail because of wrong number of args, etc.
  let f = newPyFrame(funcObj)
  if f.isThrownException:
    unreachable("funcObj shouldn't have any arg issue")
  let retObj = f.evalFrame
  if retObj.isThrownException:
    return retObj
  tpMagic(Type, new)(@[pyTypeObjectType, name, newPyTuple(@[]), f.toPyDict()])


# interfaces to upper level
proc runCode*(co: PyCodeObject): PyObject = 
  when defined(debug):
    echo co
  let fun = newPyFunc(newPyString("<module>"), co, newPyDict())
  let f = newPyFrame(fun)
  f.evalFrame


proc runString*(input: TaintedString, fileName: string): PyObject = 
  let compileRes = compile(input, fileName)
  if compileRes.isThrownException:
    return compileRes
  runCode(PyCodeObject(compileRes))
