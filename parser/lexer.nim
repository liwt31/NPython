import re
from strutils import strip
from os import commandLineParams
import typetraits

from token import Token

type
  TokenLexer = ref object 
    token: Token
    regex: Regex
    matcher: proc(str: string)

  Node = ref object
    token: Token
    content: string

  Lexer = ref object
    indentLevel: int

  SyntaxError = object of Exception


var regexName = re(r"\b[a-zA-Z_]+[a-zA-Z_0-9]*\b")
var regexNumber = re(r"\b\d+\b")

proc getNextToken(input: TaintedString, idx: int): (Node, int) = 
  return (Node(token: Token.Name, content: "sdf"), idx+1)


proc initNode(token: Token, content = ""): Node = 
  new(result)
  result.token = token
  result.content = content


proc initLexer(): Lexer = 
  new(result)
  result.indentLevel = 0


proc lex(lexer: Lexer, input: TaintedString): seq[Node] = 

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
        result.add(initNode(Token.Dedent))
    of 0:
      discard
    else:
      for i in 0..<diff:
        result.add(initNode(Token.Indent))
  lexer.indentLevel = indentLevel

  template addRegexToken(tokenName) =
    var
      first, last: int
    (first, last) = input.findBounds(`regex tokenName`, start=idx)
    result.add(initNode(Token.tokenName, input[first..last]))
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
      result.add(initNode(Token.Equal))
      idx += 1
    of '+':
      result.add(initNode(Token.Plus))
      idx += 1
    of '(':
      result.add(initNode(Token.Lpar))
      idx += 1
    of ')':
      result.add(initNode(Token.Rpar))
      idx += 1
    of '\n':
      result.add(initNode(Token.Newline))
      idx += 1
    else:
      var node: Node
      (node, idx) = getNextToken(input, idx)
      result.add(node)

  result.add(initNode(Token.Endmarker))


proc interactiveShell() = 
  let lexer = initLexer()
  while true:
    var input: TaintedString
    stdout.write(">>> ")
    try:
      input = stdin.readline()
    except EOFError:
      quit(0)
    var node_seq: seq[Node]
    try:
      node_seq = lexer.lex(input)
    except SyntaxError:
      let
        e = getCurrentException()
      #echo repr(e)
      echo "wrong syntax"
    for node in node_seq:
      echo node[]


proc lexFile*(input: TaintedString) = 
  let lexer = initLexer()
  var node_seq = lexer.lex(input)
  for node in node_seq:
    echo node[]


when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    interactiveShell()
  else:
    let fname = args[0]
    let input = readFile(fname)
    lexFile(input)
  

