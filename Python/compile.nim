import os
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

  # node in CFG, an abstraction layer for convenient byte code offset computation
  BasicBlock = ref object
    instrSeq: seq[Instr]
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
    interactive: bool


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

proc newBasicBlock: BasicBlock =
  result = new BasicBlock
  result.seenReturn = false

proc newCompilerUnit: CompilerUnit =
  result = new CompilerUnit
  result.ste = newSymTableEntry()
  result.blocks.add(newBasicBlock())


proc newCompiler: Compiler =
  result = new Compiler
  result.units.add(newCompilerUnit())


method toTuple(instr: Instr): (OpCode, int) {.base.} =
  (instr.opCode, -1)


method toTuple(instr: ArgInstr): (OpCode, int) =
  (instr.opCode, instr.opArg)


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

proc addLoadOp(c: Compiler, nameStr: PyStrObject) = 
  let isLocal = c.tste.hasLocal(nameStr)

  var
    opArg: int
    opCode: OpCode

  if isLocal:
    opArg = c.tste.localId(nameStr)
  else:
    opArg = c.tste.nameId(nameStr)

  if isLocal:
    opCode = OpCode.LoadFast
  else:
    # locals() scope not implemented
    opCode = OpCode.LoadGlobal

  let instr = newArgInstr(opCode, opArg)
  c.addOp(instr)


proc addLoadOp(c: Compiler, name: AsdlIdentifier) =
  let nameStr = name.value
  addLoadOp(c, nameStr)


proc addStoreOp(c: Compiler, nameStr: PyStrObject) = 
  let isLocal = c.tste.hasLocal(nameStr)

  var
    opArg: int
    opCode: OpCode

  if isLocal:
    opArg = c.tste.localId(nameStr)
  else:
    opArg = c.tste.nameId(nameStr)

  if isLocal:
    opCode = OpCode.StoreFast
  else:
    opCode = OpCode.StoreGlobal

  let instr = newArgInstr(opCode, opArg)
  c.addOp(instr)


proc addStoreOp(c: Compiler, name: AsdlIdentifier) =
  let nameStr = name.value
  addStoreOp(c, nameStr)


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
  c.units.add(newCompilerUnit())
  c.tste.collectLocalVar(astNode)
  #c.compile(astNode.args)
  c.compileSeq(astNode.body)
  let co = c.units.pop.assemble
  c.tcu.addLoadConst(co)
  c.tcu.addLoadConst(astNode.name.value)
  # the second arg: simplest case (no flag)
  c.addOp(newArgInstr(OpCode.MakeFunction, 0))
  c.addStoreOp(astNode.name)


compileMethod Return:
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
  let start = newBasicBlock()
  let ending = newBasicBlock()
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
  let loop = newBasicBlock()
  let ending = newBasicBlock()
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
  if astNode.ctx of AstLoad:
    c.compile(astNode.value)
    let opArg = c.tste.nameId(astNode.attr.value)
    c.addOp(newArgInstr(OpCode.LoadAttr, opArg))
  elif astNode.ctx of AstStore:
    unreachable("store not implemented")
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
  #echo astRoot
  let c = newCompiler()
  c.compile(astRoot)
  result = c.tcu.assemble


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  echo compile(input)

