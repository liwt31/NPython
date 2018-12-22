type
  # exceptions used internally
  # not making semse... should just assert false
  InternalError* = object of Exception
  # raised when user try to do type incompatible operations
  # shoud be in python error type in ./Objects?
  #TypeError* = ref object of Exception

  SyntaxError* = object of Exception 
