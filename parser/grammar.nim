import strutils
import parseutils
import sequtils
import strformat
import sets
import tables

import token

type
  Repeat {.pure.} = enum
    None
    Star
    Plus
    Query

  GrammarNode* = ref object
    repeat*: Repeat
    firstSet*: set[Token]
    case kind: char
    of 'a': # terminal
      token: Token
    of 'A'..'H': # non-terminal
      children*: seq[GrammarNode]
    else: # + * ?
      discard

  Grammar = ref object
    token: Token
    grammarString: string
    rootNode*: GrammarNode
    cursor: int

var 
  grammarSeq*: seq[Grammar]
  grammarSet* =  initTable[Token, Grammar]()
  firstSet = initTable[Token, set[Token]]()


# Grammar of EBNF used in python
# ast: a seq of B with E as attribute, if only one element, factored to one B with E
# A -> B E H                               
# B -> C | D | a                           ast: C or D or reserved name or grammar token
# C -> '[' F ']'                           ast: a seq of A by expanding F
# ast: same as above, rename to F, D info in attribute
# D -> '(' F ')'                           
# E -> + | * | \epsilon
# F -> A G                                 ast: a seq of A, if only one element, factored 
# G -> '|' A G | \epsilon                  ast: a seq of A
# H -> A | \epsilon                        ast: nil or single A

proc matchA(grammar: Grammar): GrammarNode  
proc matchB(grammar: Grammar): GrammarNode  
proc matchC(grammar: Grammar): GrammarNode  
proc matchD(grammar: Grammar): GrammarNode  
proc matchE(grammar: Grammar): GrammarNode  
proc matchF(grammar: Grammar): GrammarNode  
proc matchG(grammar: Grammar): GrammarNode  
proc matchH(grammar: Grammar): GrammarNode  


proc newGrammarNode(name: string, tokenString=""): GrammarNode = 
  new result
  case name[0]
  of 'A'..'H', '+', '?', '*':
    result.kind = name[0]
  of 'a':
    result.kind = 'a'
    result.token = strTokenMap[tokenString]
  else:
    raise newException(ValueError, fmt"unknown name: {name}")


proc newGrammar(name: string, grammarString: string): Grammar = 
  new result
  result.token = strTokenMap[name]
  result.grammarString = grammarString
  result.rootNode = matchF(result)
  result.cursor = 0


proc errorGrammar(grammar: Grammar) =
  let
    s = grammar.grammarString
    c = grammar.cursor

  let msg = fmt"invalid syntax for {s[0..<c]} $${s[c]}$$ {s[c+1..^1]}"
  raise newException(ValueError, msg)


proc optional(node: GrammarNode): bool = 
  node.repeat == Repeat.Star or node.repeat == Repeat.Query


proc isTerminator(node: GrammarNode): bool = 
  node.kind == 'a'


proc `$`*(grammarNode: GrammarNode): string = 
  var stringSeq: seq[string]
  var tail: string
  case grammarNode.repeat
  of Repeat.None:
    discard
  of Repeat.Star:
    tail = "*"
  of Repeat.Plus:
    tail = "+"
  of Repeat.Query:
    tail = "?"
  var name: string
  case grammarNode.kind
  of 'a':
    name = $grammarNode.token
  else:
    name = $grammarNode.kind
  stringSeq.add(name & tail)
  for child in grammarNode.children:
    if child == nil:
      continue
    for substr in split($(child), "\n"):
      stringSeq.add("    " & substr)
  result = stringSeq.join("\n")


proc `$`*(grammar: Grammar): string =
  result = [$grammar.token & " " & grammar.grammarString, $(grammar.rootNode)].join("\n")


proc getChar(grammar: Grammar): char =
  grammar.cursor.inc grammar.grammarString.skipWhitespace(grammar.cursor)
  result = grammar.grammarString[grammar.cursor]


proc exhausted(grammar: Grammar): bool =
  result = grammar.cursor == len(grammar.grammarString)


proc matchA(grammar: Grammar): GrammarNode = 
  var
    b = matchB(grammar)
    e = matchE(grammar)
    h = matchH(grammar)
  if e != nil:
    case e.kind
    of '+':
      assert b.repeat == Repeat.None
      b.repeat = Repeat.Plus
    of '*':
      assert b.repeat == Repeat.None
      b.repeat = Repeat.Star
    else:
      assert false
  if h != nil:
    result = newGrammarNode("A")
    result.children.add(b)
    if h.repeat != Repeat.None or h.kind == 'F' or h.isTerminator: # if factored
      result.children.add(h)
    else:
      result.children = result.children.concat(h.children)
  else:
    result = b
    

proc matchB(grammar: Grammar): GrammarNode = 
  case grammar.getChar()
  of '[':
    result = matchC(grammar)
  of '(':
    result = matchD(grammar)
  of '\'':
    inc(grammar.cursor)
    var prev = grammar.cursor
    grammar.cursor.inc(grammar.grammarString.skipUntil('\'', grammar.cursor))
    inc(grammar.cursor)
    let substr = grammar.grammarString[prev..grammar.cursor-2]
    result = newGrammarNode("a", substr)
  else:
    let first = grammar.cursor
    grammar.cursor.inc(grammar.grammarString.skipWhile(IdentStartChars, grammar.cursor))
    let substr = grammar.grammarString[first..<grammar.cursor]
    result = newGrammarNode("a", substr)


proc matchC(grammar: Grammar): GrammarNode =
  case grammar.getChar
  of '[':
    inc(grammar.cursor)
  else:
    errorGrammar(grammar)
  result = matchF(grammar)
  result.repeat = Repeat.Query
  case grammar.getChar
  of ']':
    inc(grammar.cursor)
  else:
    errorGrammar(grammar)


proc matchD(grammar: Grammar): GrammarNode = 
  case grammar.getChar()
  of '(':
    inc(grammar.cursor)
  else:
    errorGrammar(grammar)
  result = matchF(grammar)
  case grammar.getChar()
  of ')':
    inc(grammar.cursor)
  else:
    errorGrammar(grammar)


proc matchE(grammar: Grammar): GrammarNode = 
  if grammar.exhausted:
    return
  case grammar.getChar()
  of '+': 
    result = newGrammarNode("+")
    inc(grammar.cursor)
  of '*':
    
    result = newGrammarNode("*")
    inc(grammar.cursor)
  else:
    discard


proc matchF(grammar: Grammar): GrammarNode = 
  let a = matchA(grammar)
  let g = matchG(grammar)
  if g != nil:
    result = newGrammarNode("F")
    result.children.add(a)
    result.children = result.children.concat(g.children)
  else:
    result = a


proc matchG(grammar: Grammar): GrammarNode = 
  if grammar.exhausted:
    return
  case grammar.getChar
  of '|':
    result = newGrammarNode("G")
    inc(grammar.cursor)
    result.children.add(matchA(grammar))
    let g = matchG(grammar)
    if g != nil:
      result.children = result.children.concat(g.children)
  else:
    discard


proc matchH(grammar: Grammar): GrammarNode =
  if grammar.exhausted:
    return
  case grammar.getChar
  of IdentStartChars, '[', '(', '\'': # handcrafted FirstSet for A
    result = matchA(grammar)
  else:
    return


proc lexGrammar = 
  let text = readFile("Grammar")
  let lines = text.splitLines()
  var 
    lineIdx = 0
  while lineIdx < lines.len():
    var line = lines[lineIdx]
    if line.len() < 1 or line[0] == '#':
      inc(lineIdx)
      continue
    let colonIdx = line.find(':')
    if colonIdx == -1:
      quit("Unknown syntax at {lineIdx}: {line}")
    let name = line[0..<colonIdx]

    var
      numPar = 0
      numBra = 0
      startColIdx = colonIdx + 1
      colIdx = startColIdx
      grammarString = ""
    if startColIdx == line.len():
      quit("Unknown syntax at {lineIdx}: {line}")
    while true:
      while colIdx < line.len():
        # ")(" will lead to bug, assume not gonna happen
        case line[colIdx]
        of '(':
          inc(numPar)
        of ')':
          dec(numPar)
        of '[':
          inc(numBra)
        of ']':
          dec(numBra)
        else:
          discard
        inc(colIdx)
      grammarString &= line[startColIdx..<colIdx]
      if numPar == 0 and numBra == 0:
        break
      else:
        inc(lineIdx)
        line = lines[lineIdx]
        startColIdx = 0
        # skip spaces
        while line[startColIdx] == ' ':
          inc(startColIdx)
        # spare a space
        startColIdx = max(startColIdx - 1, 0)
        colIdx = startColIdx
    inc(lineIdx)
    let grammar = newGrammar(name, grammarString)
    grammarSet.add(strTokenMap[name], grammar)
    grammarSeq.add(grammar)


# forward
proc genFirstSet(grammar: Grammar)


proc genFirstSet(node: GrammarNode, allChildren = false) =
  if node.isTerminator:
    if not node.token.isTerminator:
      if not firstSet.hasKey(node.token):
        genFirstSet(grammarSet[node.token])
      node.firstSet.incl(firstSet[node.token])
    else:
      node.firstSet.incl(node.token)
  else:
    if allChildren:
      for child in node.children:
        genFirstSet(child, true)
    case node.kind
    of 'A':
      for child in node.children:
        genFirstSet(child)
        node.firstSet.incl(child.firstSet)
        if not child.optional:
          break
    of 'F':
      for child in node.children:
        genFirstSet(child)
        node.firstSet.incl(child.firstSet)
    else:
      assert false
    

proc genFirstSet(grammar: Grammar) =
  genFirstSet(grammar.rootNode)
  firstSet[grammar.token] = grammar.rootNode.firstSet


proc genFirstSet =
  for grammar in grammarSeq:
    if firstSet.hasKey(grammar.token):
      continue
    genFirstSet(grammar)
  # generate first set for every node
  for grammar in grammarSeq:
    genFirstSet(grammar.rootNode, true)


# make sure LL1 can work by detecting conflicts
proc validateFirstSet = 
  for grammar in grammarSeq:
    var toVisit = @[grammar.rootNode]
    while 0 < toVisit.len:
      var curNode = toVisit.pop
      assert curNode != nil
      if not curNode.isTerminator:
        for child in curNode.children:
          if child.kind == 'A' or child.kind == 'F':
            toVisit.add(child)
      case curNode.kind
      of 'A': 
        var i: int
        while i < curNode.children.len:
          var child = curNode.children[i]
          var accumulate: set[Token]
          while child.optional:
            if (accumulate * child.firstSet).card != 0:
              echo fmt"Conflict for {grammar.token} in A"
            else:
              accumulate.incl(child.firstSet)
            inc i
            if not (i < curNode.children.len):
              break
            child = curNode.children[i]
          inc i
      of 'F':
        var accumulate: set[Token]
        for child in curNode.children:
          if (child.firstSet * accumulate).card != 0:
            echo fmt"Conflict for {grammar.token} in F"
          else:
            accumulate.incl(child.firstSet)
      of 'B'..'E', 'G', 'H', '+', '*', '?': # shouldn't appear in AST
        assert false
      else:
        discard


lexGrammar()

genFirstSet()

validateFirstSet()



when isMainModule:
  for grammar in grammarSeq:
    discard
    #echo name & grammar.grammarString
    #echo grammar.rootNode
    #echo "### " & toSeq(firstSet[name].items).join(" ")

  

