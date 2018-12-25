import re
import deques
import sets
import strformat
import strutils
import os
import typetraits
import tables
import parseutils

import token
import ../Utils/utils

type

  Mode* {.pure.} = enum
    Single
    File
    Eval

  Lexer* = ref object
    indentLevel: int
    tokenNodes*: Deque[TokenNode] # might be consumed by parser

var regexName = re(r"\b[a-zA-Z_]+[a-zA-Z_0-9]*\b")
var regexNumber = re(r"\b\d*\.?\d+([eE][-+]?\d+)?\b")


proc newTokenNode*(token: Token, content = ""): TokenNode = 
  new result
  if token == Token.Name and content in reserveNameSet: 
    try:
      result.token = strTokenMap[content]
    except KeyError:
      assert false
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


# the following function can probably be generated by a macro...
proc getNextToken(
  lexer: Lexer, 
  line: TaintedString, 
  idx: var int): TokenNode {. raises: [SyntaxError] .} = 
  template addRegexToken(tokenName:untyped, msg:string) =
    var (first, last) = line.findBounds(`regex tokenName`, start=idx)
    if first == -1:
      raiseSyntaxError(msg)
    idx = last+1
    result = newTokenNode(Token.tokenName, line[first..last])

  template addSingleCharToken(tokenName) = 
    result = newTokenNode(Token.tokenName)
    inc idx

  template tailing(t: char): bool = 
    (idx < line.len - 1) and line[idx+1] == t

  template addSingleOrDoubleCharToken(tokenName1, tokenName2: untyped, c:char) = 
    if tailing(c):
      result = newTokenNode(Token.tokenName2)
      idx += 2
    else:
      addSingleCharToken(tokenName1)

  case line[idx]
  of 'a'..'z', 'A'..'Z', '_': # possibly a name
    addRegexToken(Name, "Invalid identifier")
  of '0'..'9':
    addRegexToken(Number, "Invalid number")
  of '"', '\'':
    let pairingChar = line[idx]
    
    if idx == line.len - 1:
      raiseSyntaxError("Invalid string syntax")
    let l = line.skipUntil(pairingChar, idx+1)
    if idx + l + 1 == line.len: # pairing `"` not found
      raiseSyntaxError("Invalid string syntax")
    else:
      result = newTokenNode(Token.String, line[idx+1..idx+l])
      idx += l + 2

  of '\n':
    result = newTokenNode(Token.Newline)
    idx += 1
  of '(':
    addSingleCharToken(Lpar)
  of ')':
    addSingleCharToken(Rpar)
  of '[':
    addSingleCharToken(Lsqb)
  of ']':
    addSingleCharToken(Rsqb)
  of ':':
    addSingleCharToken(Colon)
  of ',':
    addSingleCharToken(Comma)
  of ';':
    addSingleCharToken(Semi)
  of '+': 
    addSingleOrDoubleCharToken(Plus, PlusEqual, '=')
  of '-':
    if tailing('='):
      result = newTokenNode(Token.MinEqual)
      idx += 2
    elif tailing('>'):
      result = newTokenNode(Token.Rarrow)
      idx += 2
    else:
      addSingleCharToken(Minus)
  of '*':
    if tailing('*'):
      inc idx
      if tailing('='):
        result = newTokenNode(Token.DoubleStarEqual)
        idx += 2
      else:
        result = newTokenNode(Token.DoubleStar)
        inc idx
    else:
      addSingleCharToken(Star)
  of '/':
    if tailing('/'):
      inc idx
      if tailing('='):
        result = newTokenNode(Token.DoubleSlashEqual)
        idx += 2
      else:
        result = newTokenNode(Token.DoubleSlash)
        inc idx
    else:
      addSingleCharToken(Slash)
  of '|':
    addSingleOrDoubleCharToken(Vbar, VbarEqual, '=')
  of '&':
    addSingleOrDoubleCharToken(Amper, AmperEqual, '=')
  of '<': 
    if tailing('='):
      result = newTokenNode(Token.LessEqual)
      idx += 2
    elif tailing('<'):
      inc idx
      if tailing('='):
        result = newTokenNode(Token.LeftShiftEqual)
        idx += 2
      else:
        result = newTokenNode(Token.LeftShift)
        inc idx
    elif tailing('>'):
      raiseSyntaxError("<> in PEP401 not implemented")
    else:
      addSingleCharToken(Less)
  of '>':
    if tailing('='):
      result = newTokenNode(Token.GreaterEqual)
      idx += 2
    elif tailing('>'):
      inc idx
      if tailing('='):
        result = newTokenNode(Token.RightShiftEqual)
        idx += 2
      else:
        result = newTokenNode(Token.RightShift)
        inc idx
    else:
      addSingleCharToken(Greater)
  of '=': 
    addSingleOrDoubleCharToken(Equal, EqEqual, '=')
  of '.':
    if idx < line.len - 2 and line[idx+1] == '.' and line[idx+2] == '.':
      result = newTokenNode(Token.Ellipsis)
      idx += 3
    else:
      addSingleCharToken(Dot)
  of '%':
    addSingleOrDoubleCharToken(Percent, PercentEqual, '=')
  of '{', '}':
    raiseSyntaxError("\"{\"  \"}\" not implemented")
  of '!':
    if tailing('='):
      addSingleCharToken(NotEqual)
    else:
      raiseSyntaxError("Single ! not allowed")
  of '~':
    addSingleCharToken(Tilde)
  of '^':
    addSingleOrDoubleCharToken(Circumflex, CircumflexEqual, '=')
  of '@':
    addSingleOrDoubleCharToken(At, AtEqual, '=')
  else: 
    raiseSyntaxError(fmt"Unknown character {line[idx]}")
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
    raiseSyntaxError("Indentation must be 4 spaces.")
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
    of '#':
      break
    else:
      lexer.add(getNextToken(lexer, line, idx))
  lexer.add(Token.NEWLINE)


proc interactiveShell() {. raises: [] .} = 
  let lexer = newLexer()
  while true:
    var input: TaintedString
    try:
      stdout.write(">>> ")
      input = stdin.readline()
    except EOFError:
      quit(0)
    except IOError:
      echo "IOError"
      quit(1)

    try:
      lexer.lex(input)
    except SyntaxError:
      echo getCurrentExceptionMsg()

    for node in lexer.tokenNodes:
      echo node
    lexer.tokenNodes.clear


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


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    interactiveShell()
  else:
    let fname = args[0]
    let input = readFile(fname)
    let lexer = lexString(input)
    echo lexer.tokenNodes
  

