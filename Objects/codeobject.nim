import strformat
import strutils

import pyobject
import stringobject
import ../Python/[opcode, symtable]

type
  OpArg* = int

declarePyType Code(tpToken):
    code: seq[(OpCode, OpArg)] # for convenient and not performance critical accessing
    opCodes: ptr OpCode # array of opcodes with `length`, same with `code`
    opArgs: ptr OpArg # array of args with `length`, same with `code`
    constants: seq[PyObject]

    # store the strings for exception and debugging infomation
    names: seq[PyStrObject]
    localVars: seq[PyStrObject]
    cellVars: seq[PyStrObject]
    freeVars: seq[PyStrObject]

    argNames: seq[PyStrObject]
    argScopes: seq[(Scope, int)]

    # for tracebacks
    codeName: PyStrObject
    fileName: PyStrObject


# most attrs of code objects are set in compile.nim
proc newPyCode*(codeName, fileName: PyStrObject, length: int): PyCodeObject =
  proc finalizer(obj: PyCodeObject) = 
    dealloc(obj.opCodes)
    dealloc(obj.opArgs)

  newPyCodeFinalizer(result, finalizer)
  result.opCodes = createU(OpCode, length)
  result.opArgs = createU(OpArg, length)
  result.codeName = codeName
  result.fileName = fileName

proc len*(code: PyCodeObject): int {. inline .} = 
  code.code.len

template `[]`*(opCodes: ptr OpCode, idx: int): OpCode = 
  cast[ptr OpCode](cast[int](opCodes) + idx * sizeof(OpCode))[]

template `[]`*(opArgs: ptr OpArg, idx: int): OpArg = 
  cast[ptr OpArg](cast[int](opArgs) + idx * sizeof(OpArg))[]

template `[]=`(opCodes: ptr OpCode, idx: int, value: OpCode) = 
  cast[ptr OpCode](cast[int](opCodes) + idx * sizeof(OpCode))[] = value

template `[]=`(opArgs: ptr OpArg, idx: int, value: OpArg) = 
  cast[ptr OpArg](cast[int](opArgs) + idx * sizeof(OpArg))[] = value

proc addOpCode*(code: PyCodeObject, 
               instr: tuple[opCode: OpCode, opArg: OpArg, lineNo: int]) = 
  code.opCodes[code.len] = instr.opCode
  code.opArgs[code.len] = instr.opArg
  code.code.add((instr.opCode, instr.opArg))

implCodeMagic repr:
  let codeName = self.codeName.str
  let fileName = self.fileName.str
  let msg = fmt("<code object {codeName} at {self.idStr}, file \"{fileName}\">")
  newPyStr(msg)

method `$`*(code: PyCodeObject): string = 
  var s: seq[string]
  s.add("Names: " & $code.names)
  s.add("Local variables: " & $code.localVars)
  s.add("Cell variables: " & $code.cellVars)
  s.add("Free variables: " & $code.freeVars)
  # temperary workaround for code obj in the disassembly
  var otherCodes: seq[PyCodeObject]
  for idx, opArray in code.code:
    let opCode = OpCode(opArray[0])
    let opArg = opArray[1]
    var line = fmt"{idx:>10} {opCode:<30}"
    if opCode in hasArgSet:
      line &= fmt"{opArg:<4}"
      case opCode
      of OpCode.LoadName, OpCode.StoreName, OpCode.LoadAttr, 
        OpCode.LoadGlobal, OpCode.StoreGlobal:
        line &= fmt" ({code.names[opArg]})"
      of OpCode.LoadConst:
        let constObj = code.constants[opArg]
        if constObj.ofPyCodeObject:
          let otherCode = PyCodeObject(constObj)
          otherCodes.add(otherCode)
          let reprStr = tpMagic(Code, repr)(otherCode)
          line &= fmt" ({reprStr})"
        else:
          line &= fmt" ({code.constants[opArg]})"
      of OpCode.LoadFast, OpCode.StoreFast:
        line &= fmt" ({code.localVars[opArg]})"
      of OpCode.LoadDeref, OpCode.StoreDeref:
        if opArg < code.cellVars.len:
          line &= fmt" ({code.cellVars[opArg]})"
        else:
          line &= fmt" ({code.freeVars[opArg - code.cellVars.len]})"
      of OpCode.CallFunction, jumpSet, OpCode.BuildList, 
         OpCode.BuildTuple, OpCode.UnpackSequence, OpCode.MakeFunction,
         OpCode.RaiseVarargs:
        discard
      else:
        line &= " (Unknown OpCode)"
    s.add(line)
  s.add("\n")
  result = s.join("\n")
  for otherCode in otherCodes:
    result &= $otherCode

