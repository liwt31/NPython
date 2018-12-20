type
  # exceptions used internally
  # not making semse... should just assert false
  InternalError* = ref object of Exception
  # raised when user try to do type incompatible operations
  TypeError* = ref object of Exception
