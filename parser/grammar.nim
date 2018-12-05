import strutils
import parseutils
import sequtils
import strformat
import sets
import tables

from token import strTokenMap, Token

type
  Repeat {.pure.} = enum
    None
    Star
    Plus
    Query

  GrammarNode* = ref object
    name*: string
    children*: seq[GrammarNode]
    repeat*: Repeat
    firstSet*: HashSet[string]

  Grammar = ref object
    name*: string
    grammarString: string
    rootNode*: GrammarNode
    cursor: int

var 
  grammarSeq*: seq[Grammar]
  grammarNameSet* =  initTable[string, Grammar]()
  firstSet = initTable[string, HashSet[string]]()
  firstTokenSet = initTable[string, HashSet[Token]]()


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


proc newGrammarNode(name: string): GrammarNode = 
  new(result)
  result.name = name
  result.firstSet.init


proc newGrammar(name: string, grammarString: string): Grammar = 
  new(result)
  result.name = name
  result.grammarString = grammarString
  result.rootNode = matchF(result)
  result.cursor = 0


proc errorGrammar(grammar: Grammar) =
  let
    s = grammar.grammarString
    c = grammar.cursor

  quit(fmt"invalid syntax for {s[0..<c]} $${s[c]}$$ {s[c+1..^1]}")


proc optional(node: GrammarNode): bool = 
  node.repeat == Repeat.Star or node.repeat == Repeat.Query


proc `$`*(grammerNode: GrammarNode): string = 
  var stringSeq: seq[string]
  var tail: string
  case grammerNode.repeat
  of Repeat.None:
    discard
  of Repeat.Star:
    tail = "*"
  of Repeat.Plus:
    tail = "+"
  of Repeat.Query:
    tail = "?"
  stringSeq.add(grammerNode.name & tail)
  for child in grammerNode.children:
    if child == nil:
      continue
    for substr in split($(child), "\n"):
      stringSeq.add("    " & substr)
  result = stringSeq.join("\n")


proc `$`*(grammar: Grammar): string =
  result = [grammar.name & " " & grammar.grammarString, $(grammar.rootNode)].join("\n")


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
    case e.name
    of "+":
      assert b.repeat == Repeat.None
      b.repeat = Repeat.Plus
    of "*":
      assert b.repeat == Repeat.None
      b.repeat = Repeat.Star
    else:
      assert false
  if h != nil:
    result = newGrammarNode("A")
    result.children.add(b)
    if h.repeat != Repeat.None or h.name == "F" or h.children.len == 0: # if factored
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
    result = newGrammarNode(substr)
  else:
    let first = grammar.cursor
    grammar.cursor.inc(grammar.grammarString.skipWhile(IdentStartChars, grammar.cursor))
    let substr = grammar.grammarString[first..<grammar.cursor]
    result = newGrammarNode(substr)


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
    grammarNameSet.add(name, grammar)
    grammarSeq.add(grammar)


# forward
proc genFirstSet(grammar: Grammar)


proc genFirstSet(node: GrammarNode, allChildren = false) =
  if len(node.children) == 0:
    if grammarNameSet.hasKey(node.name):
      if not firstSet.hasKey(node.name):
        genFirstSet(grammarNameSet[node.name])
      node.firstSet.incl(firstSet[node.name])
    else:
      node.firstSet.incl(node.name)
  else:
    if allChildren:
      for child in node.children:
        genFirstSet(child, true)
    case node.name
    of "A":
      for child in node.children:
        genFirstSet(child)
        node.firstSet.incl(child.firstSet)
        if not child.optional:
          break
    of "F":
      for child in node.children:
        genFirstSet(child)
        node.firstSet.incl(child.firstSet)
    else:
      assert false
    

proc genFirstSet(grammar: Grammar) =
  genFirstSet(grammar.rootNode)
  firstSet[grammar.name] = grammar.rootNode.firstSet


proc genFirstSet =
  for grammar in grammarSeq:
    if firstSet.hasKey(grammar.name):
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
      for child in curNode.children:
        if child.name == "A" or child.name == "F":
          toVisit.add(child)
      case curNode.name
      of "A": 
        var i: int
        while i < curNode.children.len:
          var child = curNode.children[i]
          var accumulate: HashSet[string]
          accumulate.init
          while child.optional:
            if (accumulate * child.firstSet).len != 0:
              echo fmt"Conflict for {grammar.name} in A"
            else:
              accumulate.incl(child.firstSet)
            inc i
            if not (i < curNode.children.len):
              break
            child = curNode.children[i]
          inc i
      of "F":
        var accumulate: HashSet[string]
        accumulate.init
        for child in curNode.children:
          if (child.firstSet * accumulate).len != 0:
            echo fmt"Conflict for {grammar.name} in F"
          else:
            accumulate.incl(child.firstSet)
      of "B".."E", "G", "H": # shouldn't appear in AST
        assert false
      else:
        discard


proc genFirstTokenSet = 
  for k, v in firstSet.pairs:
    let tokenSet = initSet[Token]()
    for str in v.items:
      #tokenSet.incl(strTokenMap[str])
      discard


lexGrammar()

genFirstSet()

validateFirstSet()

# maybe necessary or not... Currently not working
genFirstTokenSet()


when isMainModule:
  for grammar in grammarSeq:
    let name = grammar.name
    #echo name & grammar.grammarString
    #echo grammar.rootNode
    #echo "### " & toSeq(firstSet[name].items).join(" ")

  

