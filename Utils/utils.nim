type
  # exceptions used internally
  InternalError* = object of Exception

  SyntaxError* = object of Exception 

template raiseSyntaxError*(msg: string) = 
  raise newException(SyntaxError, msg)

template unreachable*(msg = "Shouldn't be here") = 
  raise newException(InternalError, msg)


