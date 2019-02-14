import regex
import deques
import sets
import strformat
import strutils
import typetraits
import tables
import parseutils

import token
import ../Utils/[utils, compat]

type
  # save source file for traceback info
  Source = ref object
    lines: seq[string]

  Mode* {.pure.} = enum
    Single
    File
    Eval

  Lexer* = ref object
    indentLevel: int
    lineNo: int
    tokenNodes*: seq[TokenNode] # might be consumed by parser
    fileName*: string

var sourceFiles = initTable[string, Source]()

proc addSource*(filePath, content: string) = 
  if not sourceFiles.hasKey(filePath):
    sourceFiles[filePath] = new Source
  let s = sourceFiles[filePath]
  # s.lines.add content.split("\n")
  s.lines.addCompat content.split("\n")

proc getSource*(filePath: string, lineNo: int): string = 
  # lineNo starts from 1!
  sourceFiles[filePath].lines[lineNo-1]

proc `$`*(lexer: Lexer): string = 
  $lexer.tokenNodes

var regexName = re(r"\b[a-zA-Z_]+[a-zA-Z_0-9]*\b")
var regexNumber = re(r"\b\d*\.?\d+([eE][-+]?\d+)?\b")


# used in parser.nim to construct non-terminators
proc newTokenNode*(token: Token, 
                   lineNo = -1, colNo = -1,
                   content = ""): TokenNode = 
  new result
  if token == Token.Name and content in reserveNameSet: 
    try:
      result.token = strTokenMap[content]
    except KeyError:
      unreachable
  else:
    result.token = token
    case token
    of contentTokenSet:
      assert content != ""
      result.content = content
    else:
      assert content == ""
  assert result.token != Token.NULLTOKEN
  if result.token.isTerminator:
    assert -1 < lineNo and -1 < colNo
    result.lineNo = lineNo
    result.colNo = colNo
  else:
    assert lineNo < 0 and colNo < 0


proc newLexer*(fileName: string): Lexer = 
  new result
  result.fileName = fileName

# when we need a fresh start in interactive mode
proc clearTokens*(lexer: Lexer) = 
  # notnull checking issue for the compiler. gh-10651
  if lexer.tokenNodes.len != 0:
    lexer.tokenNodes.setLen 0

proc clearIndent*(lexer: Lexer) = 
  lexer.indentLevel = 0

proc add(lexer: Lexer, token: TokenNode) = 
  lexer.tokenNodes.add(token)

proc add(lexer: Lexer, token: Token, colNo:int) = 
  assert token.isTerminator
  lexer.add(newTokenNode(token, lexer.lineNo, colNo))


proc dedentAll*(lexer: Lexer) = 
  while lexer.indentLevel != 0:
    lexer.add(Token.Dedent, lexer.indentLevel * 4)
    dec lexer.indentLevel


# the following function can probably be generated by a macro...
proc getNextToken(
  lexer: Lexer, 
  line: TaintedString, 
  idx: var int): TokenNode {. raises: [SyntaxError, InternalError] .} = 

  template raiseSyntaxError(msg: string) = 
    # fileName set elsewhere
    raiseSyntaxError(msg, "", lexer.lineNo, idx)

  template addRegexToken(tokenName:untyped, msg:string) =
    var m: RegexMatch
    if not line.find(`regex tokenName`, m, start=idx):
      raiseSyntaxError(msg)
    let first = m.boundaries.a
    let last = m.boundaries.b
    idx = last + 1
    result = newTokenNode(Token.tokenName, lexer.lineNo, first, line[first..last])

  template addSingleCharToken(tokenName) = 
    result = newTokenNode(Token.tokenName, lexer.lineNo, idx)
    inc idx

  template tailing(t: char): bool = 
    (idx < line.len - 1) and line[idx+1] == t

  template addSingleOrDoubleCharToken(tokenName1, tokenName2: untyped, c:char) = 
    if tailing(c):
      result = newTokenNode(Token.tokenName2, lexer.lineNo, idx)
      idx += 2
    else:
      addSingleCharToken(tokenName1)

  template newTokenNodeWithNo(Tk): TokenNode = 
      newTokenNode(Token.Tk, lexer.lineNo, idx)

  case line[idx]
  of 'a'..'z', 'A'..'Z', '_':
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
      result = newTokenNode(Token.String, lexer.lineNo, idx, line[idx+1..idx+l])
      idx += l + 2

  of '\n':
    result = newTokenNodeWithNo(Newline)
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
      result = newTokenNodeWithNo(MinEqual)
      idx += 2
    elif tailing('>'):
      result = newTokenNodeWithNo(Rarrow)
      idx += 2
    else:
      addSingleCharToken(Minus)
  of '*':
    if tailing('*'):
      inc idx
      if tailing('='):
        result = newTokenNodeWithNo(DoubleStarEqual)
        idx += 2
      else:
        result = newTokenNodeWithNo(DoubleStar)
        inc idx
    else:
      addSingleCharToken(Star)
  of '/':
    if tailing('/'):
      inc idx
      if tailing('='):
        result = newTokenNodeWithNo(DoubleSlashEqual)
        idx += 2
      else:
        result = newTokenNodeWithNo(DoubleSlash)
        inc idx
    else:
      addSingleCharToken(Slash)
  of '|':
    addSingleOrDoubleCharToken(Vbar, VbarEqual, '=')
  of '&':
    addSingleOrDoubleCharToken(Amper, AmperEqual, '=')
  of '<': 
    if tailing('='):
      result = newTokenNodeWithNo(LessEqual)
      idx += 2
    elif tailing('<'):
      inc idx
      if tailing('='):
        result = newTokenNodeWithNo(LeftShiftEqual)
        idx += 2
      else:
        result = newTokenNodeWithNo(LeftShift)
        inc idx
    elif tailing('>'):
      raiseSyntaxError("<> in PEP401 not implemented")
    else:
      addSingleCharToken(Less)
  of '>':
    if tailing('='):
      result = newTokenNodeWithNo(GreaterEqual)
      idx += 2
    elif tailing('>'):
      inc idx
      if tailing('='):
        result = newTokenNodeWithNo(RightShiftEqual)
        idx += 2
      else:
        result = newTokenNodeWithNo(RightShift)
        inc idx
    else:
      addSingleCharToken(Greater)
  of '=': 
    addSingleOrDoubleCharToken(Equal, EqEqual, '=')
  of '.':
    if idx < line.len - 2 and line[idx+1] == '.' and line[idx+2] == '.':
      result = newTokenNodeWithNo(Ellipsis)
      idx += 3
    else:
      addSingleCharToken(Dot)
  of '%':
    addSingleOrDoubleCharToken(Percent, PercentEqual, '=')
  of '{':
    addSingleCharToken(Lbrace)
  of '}':
    addSingleCharToken(Rbrace)
  of '!':
    if tailing('='):
      inc idx
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


proc lexOneLine(lexer: Lexer, line: TaintedString) = 
  # process one line at a time
  assert line.find("\n") == -1

  var idx = 0

  while idx < line.len and line[idx] == ' ':
    inc(idx)
  if idx == line.len or line[idx] == '#': # full of spaces or comment line
    return

  if idx mod 4 != 0:
    raiseSyntaxError("Indentation must be 4 spaces.", "", lexer.lineNo, 0)
  let indentLevel = idx div 4
  let diff = indentLevel - lexer.indentLevel 
  if diff < 0:
    for i in diff..<0:
      lexer.add(Token.Dedent, (lexer.indentLevel+i)*4)
  else:
    for i in 0..<diff:
      lexer.add(Token.Indent, (lexer.indentLevel+i)*4)
  lexer.indentLevel = indentLevel

  while idx < line.len:
    case line[idx]
    of ' ':
      inc idx
    of '#':
      break
    else:
      lexer.add(getNextToken(lexer, line, idx))
  lexer.add(Token.NEWLINE, idx)


proc lexString*(lexer: Lexer, input: string, mode=Mode.File) = 
  assert mode != Mode.Eval # eval not tested

  # interactive mode and an empty line
  if mode == Mode.Single and input.len == 0:
    lexer.dedentAll
    lexer.add(Token.NEWLINE, 0)
    inc lexer.lineNo
    addSource(lexer.fileName, input)
    return

  for line in input.split("\n"):
    # lineNo starts from 1
    inc lexer.lineNo
    addSource(lexer.fileName, input)
    lexer.lexOneLine(line)

  when defined(debug):
    echo lexer.tokenNodes

  case mode
  of Mode.File:
    lexer.dedentAll
    lexer.add(Token.Endmarker, 0)
  of Mode.Single:
    discard
  of Mode.Eval:
    lexer.add(Token.Endmarker, 0)

