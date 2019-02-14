type
  # exceptions used internally
  InternalError* = object of Exception

  SyntaxError* = ref object of Exception 
    fileName*: string
    lineNo*: int
    colNo*: int

  # internal error for wrong type of dict function (`hash` and `eq`) return value
  DictError* = object of Exception

proc newSyntaxError(msg, fileName: string, lineNo, colNo: int): SyntaxError = 
  new result
  result.msg = msg
  result.fileName = fileName
  result.lineNo = lineNo
  result.colNo = colNo


template raiseSyntaxError*(msg: string, fileName:string, lineNo=0, colNo=0) = 
  raise newSyntaxError(msg, fileName, lineNo, colNo)


template unreachable*(msg = "Shouldn't be here") = 
  # let optimizer to eliminate related branch
  when not defined(release):
    raise newException(InternalError, msg)
