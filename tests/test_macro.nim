import macros

type
  Token {.pure.} = enum
    A
    B

dumpTree:
  echo Token.A
