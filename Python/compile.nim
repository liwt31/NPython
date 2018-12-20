import os
import sequtils
import strutils
import macros
import strformat
import tables

import Objects/pyobject
import Objects/stringobject
import Objects/codeobject
import ast
import asdl
import opcode

type
  Instr = ref object of RootObj
    opCode*: OpCode
    lineNo: int

  ArgInstr = ref object of Instr
    opArg: int

  JumpInstr = ref object of ArgInstr
    target: BasicBlock

  # node in CFG, an abstraction layer for convenient byte code offset compulation
  BasicBlock = ref object
    instrSeq: seq[Instr]
    next: BasicBlock
    seenReturn: bool
    offset: int

  # a very simple symbol table for now
  # a detailed implementation requires two passes before compilation
  # and deals with lots of syntax error
  # Now it's done during the compilation
  # because only local vairables are considered
  SymTableEntry = ref object
    sym2id: Table[string, int]
   
  # for each function, lambda, class, etc
  CompilerUnit = ref object
    ste: SymTableEntry
    blocks: seq[BasicBlock]
    # should use a dict, but we don't have hash and bunch of 
    # other things
    constants: seq[PyObject] 

  Compiler = ref object
    units: seq[CompilerUnit]
    
#[
method `$`(instr: Instr): string {. base, noSideEffect .} = 
  $instr.opCode


method `$`(instr: ArgInstr): string {. noSideEffect .} = 
  fmt"{instr.opCode:<20} {instr.oparg}"


proc `$`(cb: BasicBlock): string = 
  var s: seq[string]
  for idx, instr in cb.instrSeq:
    let offset = cb.offset + idx
    s.add(fmt"{offset:>10} {instr}")
  s.join("\n")


proc `$`(cu: CompilerUnit): string = 
  cu.blocks.join("\n\n")
  ]#


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
  result.opArg = -1 # dummy, set during assemble
  result.target = target

proc newBasicBlock: BasicBlock = 
  result = new BasicBlock
  result.seenReturn = false

proc newSymTableEntry: SymTableEntry = 
  result = new SymTableEntry
  result.sym2id = initTable[string, int]()


proc newCompilerUnit: CompilerUnit = 
  result = new CompilerUnit
  result.ste = newSymTableEntry()
  result.blocks.add(newBasicBlock())


proc newCompiler: Compiler = 
  result = new Compiler
  result.units.add(newCompilerUnit())


method toTuple(instr: Instr): (int, int) {.base.} = 
  (int(instr.opCode), -1)


method toTuple(instr: ArgInstr): (int, int) =
  (int(instr.opCode), instr.opArg)


proc constantId(cu: CompilerUnit, pyObject: PyObject): int = 
  result = cu.constants.find(pyObject)
  if result != -1:
    return
  result = cu.constants.len
  cu.constants.add(pyObject)

proc varId(ste: SymTableEntry, varName: string): int = 
  if ste.sym2id.hasKey(varName):
    return ste.sym2id[varName]
  else:
    let newId = ste.sym2id.len
    ste.sym2id.add(varName, newId)
    return newId


proc varId(ste: SymTableEntry, asdl: AsdlIdentifier): int = 
  let varName = asdl.value
  ste.varId(varName.nimString)


# the top compiler unit
proc tcu(c: Compiler): CompilerUnit = 
  c.units[^1]


# the top symbal table entry
proc tste(c: Compiler): SymTableEntry = 
  c.tcu.ste


# the top code block
proc tcb(cu: CompilerUnit): BasicBlock = 
  cu.blocks[^1]

#[
proc tcb(c: Compiler): BasicBlock = 
  c.tcu.tcb
]#

proc len(cb: BasicBlock): int = 
  cb.instrSeq.len


proc addOp(cu: CompilerUnit, instr: Instr) = 
  cu.blocks[^1].instrSeq.add(instr)


proc addOp(c: Compiler, instr: Instr) = 
  c.tcu.addOp(instr)


proc addBlock(c: Compiler, cb: BasicBlock) = 
  c.tcu.blocks.add(cb)


proc addLoadConst(cu: CompilerUnit, pyObject: PyObject) = 
  let arg = cu.constantId(pyObject)
  let instr = newArgInstr(OpCode.LoadConst, arg)
  cu.addOp(instr)


proc assemble(cu: CompilerUnit): PyCodeObject = 
  for i in 0..<cu.blocks.len-1:
    let last_block = cu.blocks[i]
    let this_block = cu.blocks[i+1]
    this_block.offset = last_block.offset + last_block.len
  for cb in cu.blocks:
    for instr in cb.instrSeq:
      if instr of JumpInstr:
        let jumpInstr = JumpInstr(instr)
        jumpInstr.opArg = jumpInstr.target.offset
  if cu.tcb.seenReturn == false:
    cu.addLoadConst(pyNone)
    cu.addOp(newInstr(OpCode.ReturnValue))
  result = new PyCodeObject
  for cb in cu.blocks:
    for instr in cb.instrSeq:
      result.code.add(instr.toTuple())
  result.constants = cu.constants
  result.names = newSeq[PyStringObject](cu.ste.sym2id.len)
  for sym, id in cu.ste.sym2id:
    result.names[id] = sym.newPystring


#[
proc assemble(c: Compiler) = 
  for cu in c.units:
    cu.assemble
]#


proc astOp2opCode(op: AsdlOperator): OpCode = 
  if op of AstAdd:
    return OpCode.BinaryAdd
  elif op of AstSub:
    return OpCode.BinarySubtract
  elif op of AstMult:
    return OpCode.BinaryMultiply
  elif op of AstDiv:
    return OpCode.BinaryTrueDivide
  elif op of AstPow:
    return OpCode.BinaryPower
  else:
    assert false


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


method compile(c: Compiler, astNode: AstNodeBase) {.base.} = 
  echo "WARNING, ast node compile method not implemented"


compileMethod Module:
  c.compileSeq(astNode.body)


compileMethod FunctionDef:
  assert astNode.decorator_list.len == 0
  assert astNode.returns == nil
  c.units.add(newCompilerUnit())
  c.compileSeq(astNode.body)
  let co = c.units.pop.assemble
  c.tcu.addLoadConst(co)
  c.tcu.addLoadConst(astNode.name.value)
  # simplest case with argument as 0 (no flag)
  c.addOp(newArgInstr(OpCode.MakeFunction, 0))
  c.addOp(newArgInstr(OpCode.StoreName, c.tste.varId(astNode.name)))


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


compileMethod Expr:
  c.compile(astNode.value)
  c.addOp(newInstr(OpCode.PopTop))


compileMethod BinOp:
  c.compile(astNode.left)
  c.compile(astNode.right)
  let opCode = astOp2opCode(astNode.op)
  c.addOp(newInstr(opCode))


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


compileMethod Constant:
  c.tcu.addLoadConst(astNode.value.value)


compileMethod Name:
  let opArg = c.tste.varId(astNode.id)
  var instr: Instr
  if astNode.ctx of AstLoad:
    instr = newArgInstr(OpCode.LoadName, opArg)
  elif astNode.ctx of AstStore:
    instr = newArgInstr(OpCode.StoreName, opArg)
  else:
    assert false
  c.addOp(instr)


compileMethod Assign:
  assert astNode.targets.len == 1
  c.compile(astNode.value)
  c.compile(astNode.targets[0])

compileMethod Lt:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.Lt)))

compileMethod Gt:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.Gt)))

compileMethod Eq:
  c.addOp(newArgInstr(OpCode.COMPARE_OP, int(CmpOp.Eq)))


proc compile*(input: TaintedString): PyCodeObject = 
  let astRoot = ast(input)
  echo astRoot
  let c = newCompiler()
  c.compile(astRoot)
  result = c.tcu.assemble


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  echo compile(input)

