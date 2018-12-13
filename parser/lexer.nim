import re
import strformat
from strutils import strip
from os import commandLineParams
import typetraits

from token import Token, TokenNode

type
  TokenLexer = ref object 
    token: Token
    regex: Regex
    matcher: proc(str: string)

  Lexer = ref object
    indentLevel: int

  SyntaxError = object of Exception

var regexName = re(r"\b[a-zA-Z_]+[a-zA-Z_0-9]*\b")
var regexNumber = re(r"\b\d+\b")

proc getNextToken(input: TaintedString, idx: int): (TokenNode, int) = 
  return (TokenNode(token: Token.Name, content: "sdf"), idx+1)


proc newTokenNode*(token: Token, content = ""): TokenNode = 
  new(result)
  result.token = token
  result.content = content


proc newLexer(): Lexer = 
  new(result)
  result.indentLevel = 0


proc lex*(lexer: Lexer, input: TaintedString): seq[TokenNode] = 

  var idx = 0

  while idx < input.len() and input[idx] == ' ':
    inc(idx)
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

  template addRegexToken(tokenName) =
    var
      first, last: int
    (first, last) = input.findBounds(`regex tokenName`, start=idx)
    result.add(newTokenNode(Token.tokenName, input[first..last]))
    idx = last+1

  while idx < input.len():
    case input[idx]
    of ' ':
      idx += 1
    of 'a'..'z', 'A'..'Z', '_': # possibly a name
      addRegexToken(Name)
    of '0'..'9':
      addRegexToken(Number)
    of '=': # todo: get 2 char lexer working (+= etc.)
      result.add(newTokenNode(Token.Equal))
      idx += 1
    of '+':
      result.add(newTokenNode(Token.Plus))
      idx += 1
    of '(':
      result.add(newTokenNode(Token.Lpar))
      idx += 1
    of ')':
      result.add(newTokenNode(Token.Rpar))
      idx += 1
    of '\n':
      result.add(newTokenNode(Token.Newline))
      idx += 1
    else:
      var node: TokenNode
      (node, idx) = getNextToken(input, idx)
      result.add(node)


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
      echo node[]


proc lexString*(input: TaintedString): seq[TokenNode] = 
  let lexer = newLexer()
  result= lexer.lex(input)
  for node in result:
    echo node[]


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    interactiveShell()
  else:
    let fname = args[0]
    let input = readFile(fname)
    discard lexString(input)
  

