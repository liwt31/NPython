import strformat
import strutils

import pyobject
import stringobject
import ../Python/[opcode, symtable]


declarePyType Code(tpToken):
    code: seq[(OpCode, int)]
    constants: seq[PyObject]

    # store the strings for exception and debugging infomation
    names: seq[PyStrObject]
    localVars: seq[PyStrObject]
    cellVars: seq[PyStrObject]
    freeVars: seq[PyStrObject]

    argScope: seq[(Scope, int)]



# code objects are initialized in compile.nim
proc newPyCode*: PyCodeObject =
  newPyCodeSimple()

proc len*(code: PyCodeObject): int {. inline .} = 
  code.code.len


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
          otherCodes.add(PyCodeObject(constObj))
          line &= " (<Code>)"
        else:
          line &= fmt" ({code.constants[opArg]})"
      of OpCode.LoadFast, OpCode.StoreFast:
        line &= fmt" ({code.localVars[opArg]})"
      of OpCode.CallFunction, jumpSet, OpCode.BuildList:
        discard
      else:
        line &= " (Unknown OpCode)"
    s.add(line)
  s.add("\n")
  result = s.join("\n")
  for otherCode in otherCodes:
    result &= $otherCode

