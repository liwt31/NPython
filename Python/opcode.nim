import macros
import sequtils

macro genOpCode(code: untyped):  untyped =
  result = newStmtList()
  # opcode tokens
  let children = toSeq(code[0].items) # convert to seq of nimNode
  result.add(
    newEnum(
      ident("OpCode"),
      children,
      true, # public and pure
      true
    )
  )

  # generate an array of opcode as map
  var constBrackets = nnkBracket.newTree()
  for child in code[0]:
    constBrackets.add(
      nnkDotExpr.newTree(
        ident("OpCode"),
        child
      )
    )

  result.add(
    newConstStmt(
      nnkPostFix.newTree(
        ident("*"),
        ident("OpCodeIndex")
      ),
      constBrackets
    )
  )


genOpCode:
  (
    POP_TOP,
    ROT_TWO,
    ROT_THREE,
    DUP_TOP,
    DUP_TOP_TWO,
    ROT_FOUR,
    NOP,
    UNARY_POSITIVE,
    UNARY_NEGATIVE,
    UNARY_NOT,
    UNARY_INVERT,
    BINARY_MATRIX_MULTIPLY,
    INPLACE_MATRIX_MULTIPLY,
    BINARY_POWER,
    BINARY_MULTIPLY,
    BINARY_MODULO,
    BINARY_ADD,
    BINARY_SUBTRACT,
    BINARY_SUBSCR,
    BINARY_FLOOR_DIVIDE,
    BINARY_TRUE_DIVIDE,
    INPLACE_FLOOR_DIVIDE,
    INPLACE_TRUE_DIVIDE,
    GET_AITER,
    GET_ANEXT,
    BEFORE_ASYNC_WITH,
    BEGIN_FINALLY,
    END_ASYNC_FOR,
    INPLACE_ADD,
    INPLACE_SUBTRACT,
    INPLACE_MULTIPLY,
    INPLACE_MODULO,
    STORE_SUBSCR,
    DELETE_SUBSCR,
    BINARY_LSHIFT,
    BINARY_RSHIFT,
    BINARY_AND,
    BINARY_XOR,
    BINARY_OR,
    INPLACE_POWER,
    GET_ITER,
    GET_YIELD_FROM_ITER,
    PRINT_EXPR,
    LOAD_BUILD_CLASS,
    YIELD_FROM,
    GET_AWAITABLE,
    INPLACE_LSHIFT,
    INPLACE_RSHIFT,
    INPLACE_AND,
    INPLACE_XOR,
    INPLACE_OR,
    WITH_CLEANUP_START,
    WITH_CLEANUP_FINISH,
    RETURN_VALUE,
    IMPORT_STAR,
    SETUP_ANNOTATIONS,
    YIELD_VALUE,
    POP_BLOCK,
    END_FINALLY,
    POP_EXCEPT,
    HAVE_ARGUMENT,
    STORE_NAME,
    DELETE_NAME,
    UNPACK_SEQUENCE,
    FOR_ITER,
    UNPACK_EX,
    STORE_ATTR,
    DELETE_ATTR,
    STORE_GLOBAL,
    DELETE_GLOBAL,
    LOAD_CONST,
    LOAD_NAME,
    BUILD_TUPLE,
    BUILD_LIST,
    BUILD_SET,
    BUILD_MAP,
    LOAD_ATTR,
    COMPARE_OP,
    IMPORT_NAME,
    IMPORT_FROM,
    JUMP_FORWARD,
    JUMP_IF_FALSE_OR_POP,
    JUMP_IF_TRUE_OR_POP,
    JUMP_ABSOLUTE,
    POP_JUMP_IF_FALSE,
    POP_JUMP_IF_TRUE,
    LOAD_GLOBAL,
    SETUP_FINALLY,
    LOAD_FAST,
    STORE_FAST,
    DELETE_FAST,
    RAISE_VARARGS,
    CALL_FUNCTION,
    MAKE_FUNCTION,
    BUILD_SLICE,
    LOAD_CLOSURE,
    LOAD_DEREF,
    STORE_DEREF,
    DELETE_DEREF,
    CALL_FUNCTION_KW,
    CALL_FUNCTION_EX,
    SETUP_WITH,
    EXTENDED_ARG,
    LIST_APPEND,
    SET_ADD,
    MAP_ADD,
    LOAD_CLASSDEREF,
    BUILD_LIST_UNPACK,
    BUILD_MAP_UNPACK,
    BUILD_MAP_UNPACK_WITH_CALL,
    BUILD_TUPLE_UNPACK,
    BUILD_SET_UNPACK,
    SETUP_ASYNC_WITH,
    FORMAT_VALUE,
    BUILD_CONST_KEY_MAP,
    BUILD_STRING,
    BUILD_TUPLE_UNPACK_WITH_CALL,
    LOAD_METHOD,
    CALL_METHOD,
    CALL_FINALLY,
    POP_FINALLY,
    EXCEPT_HANDLER,
  )


proc hasArg*(opCode: OpCode): bool = 
  opCode < OpCode.HaveArgument

