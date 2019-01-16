import os
import algorithm
import sequtils
import strutils
import macros
import strformat
import tables

import ast
import asdl
import symtable
import opcode
import ../Parser/parser
import ../Objects/[pyobject, stringobjectImpl, codeobject, noneobject]
import ../Utils/utils

type
  Instr = ref object of RootObj
    opCode*: OpCode
    lineNo: int

  ArgInstr = ref object of Instr
    opArg: int

  JumpInstr = ref object of ArgInstr
    target: BasicBlock


  BlockType {. pure .} = enum
    Misc,
    While,
    For


  # node in CFG, an abstraction layer for convenient byte code offset computation
  BasicBlock = ref object
    instrSeq: seq[Instr]
    tp: BlockType
    next: BasicBlock
    seenReturn: bool
    offset: int

  # for each function, lambda, class, etc
  CompilerUnit = ref object
    ste: SymTableEntry
    blocks: seq[BasicBlock]
    # should use a dict, but we don't have hash and bunch of 
    # other things
    constants: seq[PyObject]

  Compiler = ref object
    units: seq[CompilerUnit]
    st: SymTable
    interactive: bool

proc `$`*(i: Instr): string = 
  $i.opCode

# lineNo not implementated
proc newInstr(opCode: OpCode): Instr =
  assert(not (opCode in hasArgSet))
  result = new Instr
  result.opCode = opCode

proc newArgInstr(opCode: OpCode, opArg: int): ArgInstr =
  assert opCode in hasArgSet
  result = new ArgInstr
  result.opCode = opCode
  result.opArg = opArg

proc newJumpInstr(opCode: OpCode, target: BasicBlock): JumpInstr =
  assert opCode in jumpSet
  result = new JumpInstr
  result.opCode = opCode
  result.opArg = -1           # dummy, set during assemble
  result.target = target

proc newBasicBlock(tp=BlockType.Misc): BasicBlock =
  result = new BasicBlock
  result.seenReturn = false
  result.tp = tp

proc newCompilerUnit(st: SymTable, node: AstNodeBase): CompilerUnit =
  result = new CompilerUnit
  result.ste = st.getSte(cast[int](node))
  result.blocks.add(newBasicBlock())


proc newCompiler(root: AsdlModl): Compiler =
  result = new Compiler
  result.st = newSymTable(root)
  result.units.add(newCompilerUnit(result.st, root))


method toTuple(instr: Instr): (OpCode, int) {.base.} =
  (instr.opCode, -1)


method toTuple(instr: ArgInstr): (OpCode, int) =
  (instr.opCode, instr.opArg)

{. push inline, cdecl .}

proc constantId(cu: CompilerUnit, pyObject: PyObject): int =
  result = cu.constants.find(pyObject)
  if result != -1:
    return
  result = cu.constants.len
  cu.constants.add(pyObject)


# the top compiler unit
proc tcu(c: Compiler): CompilerUnit =
  c.units[^1]


# the top symbal table entry
proc tste(c: Compiler): SymTableEntry =
  c.tcu.ste


# the top code block
proc tcb(cu: CompilerUnit): BasicBlock =
  cu.blocks[^1]

proc tcb(c: Compiler): BasicBlock =
  c.tcu.tcb

proc len(cb: BasicBlock): int =
  cb.instrSeq.len


proc addOp(cu: CompilerUnit, instr: Instr) =
  cu.blocks[^1].instrSeq.add(instr)


proc addOp(c: Compiler, instr: Instr) =
  c.tcu.addOp(instr)


proc addOp(c: Compiler, opCode: OpCode) =
  assert (not (opCode in hasArgSet))
  c.tcu.addOp(newInstr(opCode))


proc addBlock(c: Compiler, cb: BasicBlock) =
  c.tcu.blocks.add(cb)

proc addLoadConst(cu: CompilerUnit, pyObject: PyObject) =
  let arg = cu.constantId(pyObject)
  let instr = newArgInstr(OpCode.LoadConst, arg)
  cu.addOp(instr)


proc addLoadConst(c: Compiler, pyObject: PyObject) = 
  c.tcu.addLoadConst(pyObject)

{. pop .}

proc addLoadOp(c: Compiler, nameStr: PyStrObject) = 
  let scope = c.tste.getScope(nameStr)

  var
    opArg: int
    opCode: OpCode

  case scope
  of Scope.Local:
    opArg = c.tste.localId(nameStr)
    opCode = OpCode.LoadFast
  of Scope.Global:
    opArg = c.tste.nameId(nameStr)
    opCode = OpCode.LoadGlobal
  of Scope.Cell:
    opArg = c.tste.cellId(nameStr)
    opCode = OpCode.LoadDeref
  of Scope.Free:
    opArg = c.tste.freeId(nameStr)
    opCode = OpCode.LoadDeref

  let instr = newArgInstr(opCode, opArg)
  c.addOp(instr)


proc addLoadOp(c: Compiler, name: AsdlIdentifier) =
  let nameStr = name.value
  addLoadOp(c, nameStr)


proc addStoreOp(c: Compiler, nameStr: PyStrObject) = 
  let scope = c.tste.getScope(nameStr)

  var
    opArg: int
    opCode: OpCode

  case scope
  of Scope.Local:
    opArg = c.tste.localId(nameStr)
    opCode = OpCode.StoreFast
  of Scope.Global:
    opArg = c.tste.nameId(nameStr)
    opCode = OpCode.StoreGlobal
  of Scope.Cell:
    opArg = c.tste.cellId(nameStr)
    opCode = OpCode.StoreDeref
  of Scope.Free:
    opArg = c.tste.freeId(nameStr)
    opCode = OpCode.StoreDeref

  let instr = newArgInstr(opCode, opArg)
  c.addOp(instr)


proc addStoreOp(c: Compiler, name: AsdlIdentifier) =
  let nameStr = name.value
  addStoreOp(c, nameStr)


proc assemble(cu: CompilerUnit): PyCodeObject =
  # compute offset of opcodes
  for i in 0..<cu.blocks.len-1:
    let last_block = cu.blocks[i]
    let this_block = cu.blocks[i+1]
    this_block.offset = last_block.offset + last_block.len
  # setup jump instruction destination
  for cb in cu.blocks:
    for instr in cb.instrSeq:
      if instr of JumpInstr:
        let jumpInstr = JumpInstr(instr)
        jumpInstr.opArg = jumpInstr.target.offset
  # add return if not seen
  if cu.tcb.seenReturn == false:
    cu.addLoadConst(pyNone)
    cu.addOp(newInstr(OpCode.ReturnValue))
  # convert compiler unit to code object
  result = newPyCode()
  for cb in cu.blocks:
    for instr in cb.instrSeq:
      result.code.add(instr.toTuple())
  result.constants = cu.constants
  result.names = cu.ste.namesToSeq()
  result.localVars = cu.ste.localVarsToSeq()
  # todo: add flags for faster simple function call
  result.cellVars = cu.ste.cellVarsToSeq()
  result.freeVars = cu.ste.freeVarsToSeq()
  result.argNames = newSeq[PyStrObject](cu.ste.argVars.len)
  result.argScopes = newSeq[(Scope, int)](cu.ste.argVars.len)
  for argName, argIdx in cu.ste.argVars.pairs:
    let scope = cu.ste.getScope(argName)
    var scopeIdx: int
    case scope
    of Scope.Local:
      scopeIdx = cu.ste.localId(argName)
    of Scope.Global:
      scopeIdx = cu.ste.nameId(argName)
    of Scope.Cell:
      scopeIdx = cu.ste.cellId(argName)
    of Scope.Free:
      unreachable("arguments can't be free")
    result.argNames[argIdx] = argName
    result.argScopes[argIdx] = (scope, scopeIdx)


proc makeFunction(c: Compiler, cu: CompilerUnit, functionName: PyStrObject) = 
  # take the compiler unit and make it a function on stack top
  let co = cu.assemble

  var flag: int
  # stack and flag according to CPython document:
  # 0x01 a tuple of default values for positional-only and positional-or-keyword parameters in positional order
  # 0x02 a dictionary of keyword-only parameters’ default values
  # 0x04 an annotation dictionary
  # 0x08 a tuple containing cells for free variables, making a closure
  # the code associated with the function (at TOS1)
  # the qualified name of the function (at TOS)
  
  if co.freeVars.len != 0:
    # several sources of the cellVars and freeVars:
    # * a closure in the body used it
    # * the code it self is a closure
    # In the first case, the variable may be declared in the code or in the upper level
    # In the second case, the variable must be declared in the upper level
    for name in co.freeVars:
      if c.tste.hasCell(name):
        c.addOp(newArgInstr(OpCode.LoadClosure, c.tste.cellId(name)))
      elif c.tste.hasFree(name):
        c.addOp(newArgInstr(OpCode.LoadClosure, c.tste.freeId(name)))
      else:
        unreachable
    c.addOp(newArgInstr(OpCode.BuildTuple, co.freeVars.len))
    flag = flag or 8

  c.tcu.addLoadConst(co)
  c.tcu.addLoadConst(functionName)
  # currently flag is 0 or 8
  c.addOp(newArgInstr(OpCode.MakeFunction, flag))

macro genMapMethod(methodName, code: untyped): untyped =
  result = newStmtList()
  for child in code[0]:
    let astIdent = child[0]
    let opCodeIdent = child[1]
    let newMapMethod = nnkMethodDef.newTree(
      methodName,
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
        ident("OpCode"),
        newIdentDefs(ident("astNode"), ident("Ast" & $astIdent))
      ),
      newEmptyNode(),
      newEmptyNode(),
      nnkStmtList.newTree(
        nnkDotExpr.newTree(
          ident("OpCode"),
          opCodeIdent
        )
      )
    )
    result.add(newMapMethod)

method toOpCode(op: AsdlOperator): OpCode {.base.} =
  echo op
  assert false


genMapMethod toOpCode:
  {
    Add: BinaryAdd,
    Sub: BinarySubtract,
    Mult: BinaryMultiply,
    Div: BinaryTrueDivide,
    Mod: BinaryModulo,
    Pow: BinaryPower,
    FloorDiv: BinaryFloorDivide
  }


method toOpCode(op: AsdlUnaryop): OpCode {.base.} =
  unreachable

#  unaryop = (Invert, Not, UAdd, USub)
genMapMethod toOpCode:
  {
    Invert: UnaryInvert,
    Not: UnaryNot,
    UAdd: UnaryPositive,
    USub: UnaryNegative,
  }



macro compileMethod(astNodeName, funcDef: untyped): untyped =
  result = nnkMethodDef.newTree(
    ident("compile"),
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      newEmptyNode(),
      newIdentDefs(
        ident("c"),
        ident("Compiler")
    ),
      newIdentDefs(
        ident("astNode"),
        ident("Ast" & $astNodeName)
    )
  ),
    newEmptyNode(),
    newEmptyNode(),
    funcdef,
  )


template compileSeq(c: Compiler, s: untyped) =
  for astNode in s:
    c.compile(astNode)

# todo: too many dispachers here! used astNode token to dispatch (if have spare time...)
method compile(c: Compiler, astNode: AstNodeBase) {.base.} =
  echo "!!!WARNING, ast node compile method not implemented"
  echo astNode
  echo "###WARNING, ast node compile method not implemented"
  # let it compile, the result shown is better for debugging


compileMethod Module:
  c.compileSeq(astNode.body)


compileMethod Interactive:
  c.interactive = true
  c.compileSeq(astNode.body)


compileMethod FunctionDef:
  assert astNode.decorator_list.len == 0
  assert astNode.returns == nil
  c.units.add(newCompilerUnit(c.st, astNode))
  #c.compile(astNode.args) # not useful when we don't have default args
  c.compileSeq(astNode.body)
  c.makeFunction(c.units.pop, astNode.name.value)
  c.addStoreOp(astNode.name.value)


compileMethod ClassDef:
  c.addOp(OpCode.LoadBuildClass)
  # class body function. In CPython this is more complicated because of metatype hooks,
  # treating it as normal function is a simpler approach
  c.units.add(newCompilerUnit(c.st, astNode))
  c.compileSeq(astNode.body)
  c.makeFunction(c.units.pop, astNode.name.value)

  c.addLoadConst(astNode.name.value)
  c.addOp(newArgInstr(OpCode.CallFunction, 2)) # first for the code, second for the name
  c.addStoreOp(astNode.name.value)


compileMethod Return:
  if astNode.value.isNil:
    c.addLoadConst(pyNone)
  else:
    c.compile(astNode.value)
  c.addOp(newInstr(OpCode.ReturnValue))
  c.tcb.seenReturn = true


compileMethod Assign:
  assert astNode.targets.len == 1
  c.compile(astNode.value)
  c.compile(astNode.targets[0])


compileMethod AugAssign:
  # don't do augassign as it's complicated and not necessary
  unreachable  # should be blocked by ast


compileMethod For:
  assert astNode.orelse.len == 0
  let start = newBasicBlock(BlockType.For)
  let ending = newBasicBlock()
  # used in break stmt
  start.next = ending
  c.compile(astNode.iter)
  c.addOp(OpCode.GetIter)
  c.addBlock(start)
  c.addOp(newJumpInstr(OpCode.ForIter, ending))
  if not (astNode.target of AstName):
    raiseSyntaxError("only name as loop variable")
  c.compile(astNode.target)
  c.compileSeq(astNode.body)
  c.addOp(newJumpInstr(OpCode.JumpAbsolute, start))
  c.addBlock(ending)

compileMethod While:
  assert astNode.orelse.len == 0
  let loop = newBasicBlock(BlockType.While)
  let ending = newBasicBlock()
  # used in break stmt
  loop.next = ending
  c.addBlock(loop)
  c.compile(astNode.test)
  c.addOp(newJumpInstr(OpCode.PopJumpIfFalse, ending))
  c.compileSeq(astNode.body)
  c.addOp(newJumpInstr(OpCode.JumpAbsolute, loop))
  c.addBlock(ending)


compileMethod If:
  let hasOrElse = 0 < astNode.orelse.len
  var next, ending: BasicBlock
  ending = newBasicBlock()
  if hasOrElse:
    next = newBasicBlock()
  else:
    next = ending
  # there is an optimization for `and` and `or` operators in the `test`.
  c.compile(astNode.test)
  c.addOp(newJumpInstr(OpCode.PopJumpIfFalse, next))
  c.compileSeq(astNode.body)
  if hasOrElse:
    # for now JumpForward is the same as JumpAbsolute
    # because we have no relative jump yet
    # we only have absolute jump
    # we use jump forward just to keep in sync with
    # CPython implementation
    c.addOp(newJumpInstr(OpCode.JumpForward, ending))
    c.addBlock(next)
    c.compileSeq(astNode.orelse)
  c.addBlock(ending)


compileMethod Raise:
  assert astNode.cause.isNil # should be blocked by ast
  if astNode.exc.isNil:
    c.addOp(newArgInstr(OpCode.RaiseVarargs, 0))
  else:
    c.compile(astNode.exc)
    c.addOp(newArgInstr(OpCode.RaiseVarargs, 1))

compileMethod Try:
  assert astNode.orelse.len == 0
  assert astNode.finalbody.len == 0
  assert 0 < astNode.handlers.len
  # the body here may not be necessary, I'm not sure. Add just in case.
  let body = newBasicBlock()
  var excpBlocks: seq[BasicBlock]
  for i in 0..<astNode.handlers.len:
    excpBlocks.add newBasicBlock()
  let ending = newBasicBlock()

  c.addBlock(body)
  c.addOp(newJumpInstr(OpCode.SetupFinally, excpBlocks[0]))
  c.compileSeq(astNode.body)
  c.addOp(newJumpInstr(OpCode.JumpAbsolute, ending))

  for idx, handlerObj in astNode.handlers:
    let isLast = idx == astNode.handlers.len-1

    let handler = AstExcepthandler(handlerObj)
    assert handler.name.isNil
    c.addBlock(excpBlocks[idx])
    if not handler.type.isNil:
      # In CPython duptop is required, here we don't need that, because in each
      # exception match comparison we don't pop the exception, allowing further comparison
      # c.addop(OpCode.DupTop) 
      c.compile(handler.type)
      c.addop(newArgInstr(OpCode.CompareOp, int(CmpOp.ExcpMatch)))
      if isLast:
        c.addop(newJumpInstr(OpCode.PopJumpIfFalse, ending))
      else:
        c.addop(newJumpInstr(OpCode.PopJumpIfFalse, excpBlocks[idx+1]))
    # now we are handling the exception, no need for future comparison
    c.addop(OpCode.PopTop)
    c.compileSeq(handler.body)
    if not isLast:
      c.addop(newJumpInstr(OpCode.JumpAbsolute, ending))

  c.addBlock(ending)
  c.addOp(OpCode.PopBlock)


compileMethod Assert:
  var ending = newBasicBlock()
  c.compile(astNode.test)
  c.addOp(newJumpInstr(OpCode.PopJumpIfTrue, ending))
  c.addLoadOp(newPyString("AssertionError"))
  if not astNode.msg.isNil:
    c.compile(astNode.msg)
    c.addOp(newArgInstr(OpCode.CallFunction, 1))
  c.addOp(newArgInstr(OpCode.RaiseVarargs, 1))
  c.addBlock(ending)


compileMethod Import:
  if not astNode.names.len == 1:
    unreachable
  let name = AstAlias(astNode.names[0]).name
  c.addOp(newArgInstr(OpCode.ImportName, c.tste.nameId(name.value)))
  c.addStoreOp(name)
  


compileMethod Expr:
  c.compile(astNode.value)
  if c.interactive:
    c.addOp(newInstr(OpCode.PrintExpr))
  else:
    c.addOp(newInstr(OpCode.PopTop))

compileMethod Pass:
  c.addOp(OpCode.NOP)

template findNearestLoop(blockName) = 
  for basicBlock in c.tcu.blocks.reversed:
    if basicBlock.tp in {BlockType.For, BlockType.While}:
      blockName = basicBlock
      break
  if blockName.isNil:
    raiseSyntaxError("'break' outside loop")


compileMethod Break:
  var loopBlock: BasicBlock
  findNearestLoop(loopBlock)
  c.addOp(newJumpInstr(OpCode.JumpAbsolute, loopBlock.next))


compileMethod Continue:
  var loopBlock: BasicBlock
  findNearestLoop(loopBlock)
  c.addOp(newJumpInstr(OpCode.JumpAbsolute, loopBlock))


compileMethod BoolOp:
  let ending = newBasicBlock()
  let numValues = astNode.values.len
  var op: OpCode
  if astNode.op of AstAnd:
    op = OpCode.JumpIfFalseOrPop
  elif astNode.op of AstOr:
    op = OpCode.JumpIfTrueOrPop
  else:
    unreachable
  assert 1 < numValues
  for i in 0..<numValues:
    c.compile(astNode.values[i])
    if i != numValues - 1:
      c.addOp(newJumpInstr(op, ending))
  c.addBlock(ending)


compileMethod BinOp:
  c.compile(astNode.left)
  c.compile(astNode.right)
  let opCode = astNode.op.toOpCode
  c.addOp(newInstr(opCode))



compileMethod UnaryOp:
  c.compile(astNode.operand)
  let opCode = astNode.op.toOpCode
  c.addOp(newInstr(opCode))

compileMethod Dict:
  let n = astNode.values.len
  for i in 0..<astNode.keys.len:
    c.compile(astNode.values[i])
    c.compile(astNode.keys[i])
  c.addOp(newArgInstr(OpCode.BuildMap, n))

compileMethod ListComp:
  assert astNode.generators.len == 1
  let genNode = AstComprehension(astNode.generators[0])
  c.units.add(newCompilerUnit(c.st, astNode))
  # empty list
  let body = newBasicBlock()
  let ending = newBasicBlock()
  c.addOp(newArgInstr(OpCode.BuildList, 0))
  c.addLoadOp(newPyString(".0")) # the implicit iter argument
  c.addBlock(body)
  c.addOp(newJumpInstr(OpCode.ForIter, ending))
  c.compile(genNode.target)
  c.compile(astNode.elt)
  # 1 for the object to append, 2 for the iterator
  c.addOp(newArgInstr(OpCode.ListAppend, 2))
  c.addOp(newJumpInstr(OpCode.JumpAbsolute, body))
  c.addBlock(ending)
  c.addOp(OpCode.ReturnValue)

  c.makeFunction(c.units.pop, newPyString("listcomp"))
  # prepare the first arg of the function
  c.compile(genNode.iter)
  c.addOp(OpCode.GetIter)
  c.addOp(newArgInstr(OpCode.CallFunction, 1))


compileMethod Compare:
  assert astNode.ops.len == 1
  assert astNode.comparators.len == 1
  c.compile(astNode.left)
  c.compile(astNode.comparators[0])
  c.compile(astNode.ops[0])


compileMethod Call:
  c.compile(astNode.fun)
  for arg in astNode.args:
    c.compile(arg)
  assert astNode.keywords.len == 0
  c.addOp(newArgInstr(OpCode.CallFunction, astNode.args.len))


compileMethod Attribute:
  c.compile(astNode.value)
  let opArg = c.tste.nameId(astNode.attr.value)
  if astNode.ctx of AstLoad:
    c.addOp(newArgInstr(OpCode.LoadAttr, opArg))
  elif astNode.ctx of AstStore:
    c.addOp(newArgInstr(OpCode.StoreAttr, opArg))
  else:
    unreachable

compileMethod Subscript:
  if astNode.ctx of AstLoad:
    c.compile(astNode.value)
    c.compile(astNode.slice)
    c.addOp(OpCode.BinarySubscr)
  elif astNode.ctx of AstStore:
    c.compile(astNode.value)
    c.compile(astNode.slice)
    c.addOp(OpCode.StoreSubscr)
  else:
    unreachable
  

compileMethod Constant:
  c.tcu.addLoadConst(astNode.value.value)


compileMethod Name:
  if astNode.ctx of AstLoad:
    c.addLoadOp(astNode.id)
  elif astNode.ctx of AstStore:
    c.addStoreOp(astNode.id)
  else:
    unreachable # no other context implemented


compileMethod List:
  for elt in astNode.elts:
    c.compile(elt)
  c.addOp(newArgInstr(OpCode.BuildList, astNode.elts.len))

compileMethod Tuple:
  case astNode.ctx.kind
  of AsdlExprContextTk.Load:
    for elt in astNode.elts:
      c.compile(elt)
    c.addOp(newArgInstr(OpCode.BuildTuple, astNode.elts.len))
  of AsdlExprContextTk.Store:
    c.addOp(newArgInstr(OpCode.UnpackSequence, astNode.elts.len))
    for elt in astNode.elts:
      c.compile(elt)
  else:
    unreachable

compileMethod Slice:
  var n = 2

  if astNode.lower.isNil:
    c.addLoadConst(pyNone)
  else:
    c.compile(astNode.lower)

  if astNode.upper.isNil:
    c.addLoadConst(pyNone)
  else:
    c.compile(astNode.upper)

  if not astNode.step.isNil:
    c.compile(astNode.step)
    inc n

  c.addOp(newArgInstr(OpCode.BuildSlice, n))

compileMethod Index:
  c.compile(astNode.value)


compileMethod Lt:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.Lt)))

compileMethod LtE:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.Le)))

compileMethod Gt:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.Gt)))

compileMethod GtE:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.Ge)))

compileMethod Eq:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.Eq)))

compileMethod NotEq:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.Ne)))

compileMethod In:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.In)))

compileMethod NotIn:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.NotIn)))

compileMethod Arguments:
  unreachable()


proc compile*(input: TaintedString | ParseNode): PyCodeObject =
  let astRoot = ast(input)
  let c = newCompiler(astRoot)
  c.compile(astRoot)
  c.tcu.assemble


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  echo compile(input)

