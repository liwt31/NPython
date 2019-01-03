type
  # exceptions used internally
  InternalError* = object of Exception

  SyntaxError* = object of Exception 

  # internal error for wrong type of dict function (`hash` and `eq`) return value
  DictError* = object of Exception

template raiseSyntaxError*(msg: string) = 
  raise newException(SyntaxError, msg)

template unreachable*(msg = "Shouldn't be here") = 
  # let optimizer to eliminate related branch
  when not defined(release):
    raise newException(InternalError, msg)


