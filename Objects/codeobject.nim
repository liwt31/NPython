import strformat
import strutils

import pyobject
import Python/opcode


type
  PyCodeObject* = ref object of PyObject
    code*: seq[array[2, int]]
    constants*: seq[PyObject]
    names*: seq[string]


method `$`*(code: PyCodeObject): string = 
  var s: seq[string]
  # temperary workaround for functions
  var otherCodes: seq[PyCodeObject]
  for idx, opArray in code.code:
    let opCode = OpCode(opArray[0])
    let opArg = opArray[1]
    var line = fmt"{idx:>10} {opCode:<20}"
    if opCode in hasArgSet:
      line &= fmt"{opArg:<4}"
      case opCode
      of OpCode.LoadName, OpCode.StoreName:
        line &= fmt" ({code.names[opArg]})"
      of OpCode.LoadConst:
        let constObj = code.constants[opArg]
        if constObj of PyCodeObject:
          otherCodes.add(PyCodeObject(constObj))
          line &= " (<Code>)"
        else:
          line &= fmt" ({code.constants[opArg]})"
      of OpCode.CallFunction:
        discard
      else:
        line &= " (Unknown OpCode)"
    s.add(line)
  s.add("\n")
  result = s.join("\n")
  for otherCode in otherCodes:
    result &= $otherCode

