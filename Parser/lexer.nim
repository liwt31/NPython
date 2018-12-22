import re
import deques
import sets
import strformat
import strutils
from os import commandLineParams
import typetraits
import tables

import token

type

  Mode* {.pure.} = enum
    Single
    File
    Eval

  Lexer* = ref object
    indentLevel: int
    nestingLevel: int
    tokenNodes*: Deque[TokenNode] # might be consumed by parser

var regexName = re(r"\b[a-zA-Z_]+[a-zA-Z_0-9]*\b")
var regexNumber = re(r"\b\d+\b")


proc newTokenNode*(token: Token, content = ""): TokenNode = 
  new result
  if token == Token.Name and content in reserveNameSet: 
    result.token = strTokenMap[content]
  else:
    result.token = token
    case token
    of contentTokenSet:
      assert content != ""
      result.content = content
    else:
      assert content == ""
  assert result.token != Token.NULLTOKEN


# call lexString is better than using a Lexer directly
proc newLexer: Lexer = 
  new result
  result.tokenNodes = initDeque[TokenNode]()

proc add(lexer: Lexer, token: TokenNode) = 
  lexer.tokenNodes.addLast(token)

proc add(lexer: Lexer, token: Token) = 
  lexer.add(newTokenNode(token))


proc dedentAll*(lexer: Lexer) = 
  while lexer.indentLevel != 0:
    lexer.add(Token.Dedent)
    dec lexer.indentLevel

proc getNextToken(lexer: Lexer, line: TaintedString, idx: var int): TokenNode = 
  template addRegexToken(tokenName) =
    var
      first, last: int
    (first, last) = line.findBounds(`regex tokenName`, start=idx)
    idx = last+1
    result = newTokenNode(Token.tokenName, line[first..last])

  template notExhausted: bool = 
    (idx < line.len - 1)

  case line[idx]
  of 'a'..'z', 'A'..'Z', '_': # possibly a name
    addRegexToken(Name)
  of '0'..'9':
    addRegexToken(Number)
  of '(':
    result = newTokenNode(Token.Lpar)
    inc lexer.nestingLevel
    idx += 1
  of ')':
    result = newTokenNode(Token.Rpar)
    dec lexer.nestingLevel
    idx += 1
  of ':':
    result = newTokenNode(Token.Colon)
    inc idx
  of ',':
    result = newTokenNode(Token.Comma)
    inc idx
  of ';':
    result = newTokenNode(Token.Semi)
    inc idx
  of '+': # todo: get 2 char lexer working (+= etc.)
    result = newTokenNode(Token.Plus)
    inc idx
  of '-':
    result = newTokenNode(Token.Minus)
    inc idx
  of '*':
    if notExhausted:
      case line[idx+1]
      of '*':
        result = newTokenNode(Token.DoubleStar)
        idx += 2
      else: # a failed attempt, simply let it go
        discard
    if result == nil:
      result = newTokenNode(Token.Star)
      inc idx
  of '<': 
    result = newTokenNode(Token.Less)
    inc idx
  of '>':
    result = newTokenNode(Token.Greater)
    inc idx
  of '=': 
    if notExhausted():
      case line[idx+1]
      of '=':
        result = newTokenNode(Token.Eqequal)
        idx += 2
      else:
        discard

    if result == nil:
      result = newTokenNode(Token.Equal)
      inc idx
  of '/':
    result = newTokenNode(Token.Slash)
    inc idx
  of '%':
    result = newTokenNode(Token.Percent)
    inc idx
  of '\n':
    result = newTokenNode(Token.Newline)
    idx += 1
  else: # a dummy node
    echo "Unknwon Character"
  assert result != nil

proc lex(lexer: Lexer, line: TaintedString) = 
  # process one line at a time
  assert line.find("\n") == -1

  var idx = 0

  while idx < line.len and line[idx] == ' ':
    inc(idx)
  if idx == line.len or line[idx] == '#': # full of spaces or comment line
    return

  if idx mod 4 != 0:
    echo "Wrong indentation"
    assert false
  let indentLevel = idx div 4
  let diff = indentLevel - lexer.indentLevel 
  case diff:
    of low(int).. -1:
      for i in diff..<0:
        lexer.add(Token.Dedent)
    of 0:
      discard
    else:
      for i in 0..<diff:
        lexer.add(Token.Indent)
  lexer.indentLevel = indentLevel

  while idx < line.len:
    case line[idx]
    of ' ':
      inc idx
    else:
      lexer.add(getNextToken(lexer, line, idx))
  lexer.add(Token.NEWLINE)


proc interactiveShell() = 
  let lexer = newLexer()
  while true:
    var input: TaintedString
    stdout.write(">>> ")
    try:
      input = stdin.readline()
    except EOFError:
      quit(0)
    lexer.lex(input)
    for node in lexer.tokenNodes:
      echo node


proc lexString*(input: TaintedString, mode=Mode.File, lexer: Lexer = nil): Lexer  = 
  assert mode != Mode.Eval # eval not tested
  if lexer == nil:
    result = newLexer()
  else:
    result = lexer

  if mode == Mode.Single and input.len == 0:
    result.dedentAll
    result.add(Token.NEWLINE)
    return

  for line in input.split("\n"):
    result.lex(line)

  case mode
  of Mode.File:
    result.dedentAll
    result.add(Token.Endmarker)
  of Mode.Single:
    discard
  of Mode.Eval:
    result.add(Token.Endmarker)
  for node in result.tokenNodes:
    echo node


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    interactiveShell()
  else:
    let fname = args[0]
    let input = readFile(fname)
    discard lexString(input)
  

