import re
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

  Lexer = ref object
    indentLevel: int
    nestingLevel: int

  SyntaxError = object of Exception

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


proc newLexer(): Lexer = 
  new result


proc getNextToken(lexer: Lexer, line: TaintedString, idx: var int): TokenNode = 
  template addRegexToken(tokenName) =
    var
      first, last: int
    (first, last) = line.findBounds(`regex tokenName`, start=idx)
    idx = last+1
    result = newTokenNode(Token.tokenName, line[first..last])

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
  of '<': # todo: get 2 char lexer working (+= etc.)
    result = newTokenNode(Token.Less)
    inc idx
  of '>':
    result = newTokenNode(Token.Greater)
    inc idx
  of '=': 
    result = newTokenNode(Token.Equal)
    inc idx
  of '+':
    result = newTokenNode(Token.Plus)
    inc idx
  of '-':
    result = newTokenNode(Token.Minus)
    inc idx
  of '*':
    if idx < line.len - 1:
      case line[idx+1]
      of '*':
        result = newTokenNode(Token.DoubleStar)
        idx += 2
      else: # a failed attempt, simply let it go
        discard
    if result == nil:
      result = newTokenNode(Token.Star)
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
    assert false
    result = newTokenNode(Token.NULLTOKEN)
    inc idx
  assert result != nil

proc lex(lexer: Lexer, line: TaintedString): seq[TokenNode] = 
  # process one line at a time
  assert line.find("\n") == -1

  var idx = 0

  while idx < line.len and line[idx] == ' ':
    inc(idx)
  if idx == line.len or line[idx] == '#': # full of spaces or comment line
    return

  if idx mod 4 != 0:
    raise newException(SyntaxError, "Wrong indentation")
  let indentLevel = idx div 4
  let diff = indentLevel - lexer.indentLevel 
  case diff:
    of low(int).. -1:
      for i in diff..<0:
        result.add(newTokenNode(Token.Dedent))
    of 0:
      discard
    else:
      for i in 0..<diff:
        result.add(newTokenNode(Token.Indent))
  lexer.indentLevel = indentLevel

  while idx < line.len:
    case line[idx]
    of ' ':
      inc idx
    else:
      result.add(getNextToken(lexer, line, idx))
  result.add(newTokenNode(Token.NEWLINE))


proc interactiveShell() = 
  let lexer = newLexer()
  while true:
    var input: TaintedString
    stdout.write(">>> ")
    try:
      input = stdin.readline()
    except EOFError:
      quit(0)
    var node_seq: seq[TokenNode]
    try:
      node_seq = lexer.lex(input)
    except SyntaxError:
      let
        e = getCurrentException()
      #echo repr(e)
      echo "wrong syntax"
    for node in node_seq:
      echo node


proc lexString*(input: TaintedString, mode=Mode.File): seq[TokenNode] = 
  assert mode == Mode.File # currently only support file
  let lexer = newLexer()
  for line in input.split("\n"):
    result.add lexer.lex(line)
  case mode
  of Mode.File:
    for i in 0..<lexer.indentLevel:
      result.add(newTokenNode(Token.Dedent))
    result.add(newTokenNode(Token.Endmarker))
  of Mode.Single:
    discard
  of Mode.Eval:
    result.add(newTokenNode(Token.Endmarker))
  for node in result:
    echo node




when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    interactiveShell()
  else:
    let fname = args[0]
    let input = readFile(fname)
    discard lexString(input)
  

