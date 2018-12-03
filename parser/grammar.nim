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

  GrammarNode = ref object
    name: string
    children: seq[GrammarNode]
    repeat: Repeat

  Grammar = ref object
    name*: string
    grammarString: string
    rootNode: GrammarNode
    cursor: int

  GrammarWalker = ref object
    name: string
    nodes: seq[GrammarNode]

var 
  grammarSeq*: seq[Grammar]
  grammarNameSet =  initTable[string, Grammar]()
  firstSet = initTable[string, HashSet[string]]()
  firstTokenSet = initTable[string, HashSet[Token]]()


# Grammar of EBNF used in python
# A -> B E H                               ast: a seq of B with E as attribute
# B -> C | D | a                           ast: C or D or reserved name or grammar token
# C -> '[' F ']'                           ast: a seq of A by expanding F
# D -> '(' F ')'                           ast: same as above
# E -> + | * | \epsilon
# F -> A G                                 ast: a seq of A
# G -> '|' A G | \epsilon                  ast: a seq of A
# H -> A | \epsilon

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


proc newGrammar(name: string, grammarString: string): Grammar = 
  new(result)
  result.name = name
  result.grammarString = grammarString
  result.rootNode = matchF(result)
  result.cursor = 0


proc newGrammarWalker(name: string): GrammarWalker = 
  new(result)
  result.name = name
  if not grammarNameSet.hasKey(name):
    quit(fmt"Wrong grammar name {name}")
  result.nodes.add(grammarNameSet[name].rootNode)


proc errorGrammar(grammar: Grammar) =
  let
    s = grammar.grammarString
    c = grammar.cursor

  quit(fmt"invalid syntax for {s[0..<c]} $${s[c]}$$ {s[c+1..^1]}")


proc `$`(grammerNode: GrammarNode): string = 
  var stringSeq: seq[string]
  var tail: string
  case grammerNode.repeat
  of Repeat.None:
    discard
  of Repeat.Star:
    tail = "*"
  of Repeat.Plus:
    tail = "+"
  stringSeq.add(grammerNode.name & tail)
  for child in grammerNode.children:
    if child == nil:
      continue
    for substr in split($(child), "\n"):
      stringSeq.add("    " & substr)
  result = stringSeq.join("\n")


proc getChar(grammar: Grammar): char =
  grammar.cursor.inc grammar.grammarString.skipWhitespace(grammar.cursor)
  result = grammar.grammarString[grammar.cursor]


proc exhausted(grammar: Grammar): bool =
  result = grammar.cursor == len(grammar.grammarString)


proc matchA(grammar: Grammar): GrammarNode = 
  result = newGrammarNode("A")
  var
    b = matchB(grammar)
    e = matchE(grammar)
    h = matchH(grammar)
  result.children.add(b)
  if e != nil:
    case e.name
    of "+":
      assert b.name != "C"
      b.repeat = Repeat.Plus
    of "*":
      assert b.name != "C"
      b.repeat = Repeat.Star
    else:
      assert false
  if h != nil:
    result.children = result.children.concat(h.children[0].children)
    

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
  var c = grammar.getChar()
  case c
  of '[':
    inc(grammar.cursor)
  else:
    errorGrammar(grammar)
  result = matchF(grammar)
  result.name = "C"
  c = grammar.getChar()
  case c
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
  result.name = "D"
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
  result = newGrammarNode("F")
  result.children.add(matchA(grammar))
  let g = matchG(grammar)
  if g != nil:
    result.children = result.children.concat(g.children)


proc matchG(grammar: Grammar): GrammarNode = 
  if grammar.exhausted:
    return
  result = newGrammarNode("G")
  case grammar.getChar
  of '|':
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
    result = newGrammarNode("H")
    result.children.add(matchA(grammar))
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

proc addToFirstSet(key: string, value: string ) = 
  if not firstSet.haskey(key):
    firstSet[key] = initSet[string]()
  if grammarNameSet.hasKey(value):
    let g = grammarNameSet[value]
    genFirstSet(g)
    firstSet[key].incl(firstSet[value])
  else:
    firstSet[key].incl(value)


proc genFirstSet(grammar: Grammar) =
  var toVisit = @[grammar.rootNode]
  let
    name: string = grammar.name
  # depth first (or depth only) search
  while 0 < toVisit.len:
    let curNode = toVisit.pop()
    if curNode == nil: 
      continue
    case curNode.name
    of "A":
      # observe: in Python grammar '*' never appear after the first lexeme
      # however, brakets do appear as the first lexeme, but never in 
      # succusesion
      let firstChild = curNode.children[0]
      case firstChild.name
      of "C":
        toVisit.add(firstChild)
        case curNode.children[1].name
        of "C":
          assert false
        of "D":
          toVisit.add(curNode.children[1])
        else:
          addToFirstSet(grammar.name, curNode.children[1].name)
      of "D":
        tovisit.add(firstChild)
      else:
        addToFirstSet(grammar.name, firstChild.name)
    of "C", "D", "F":
      toVisit = toVisit.concat(curNode.children)
    of "E":
      quit("Unexpected E")
    of "B", "G", "H":
      assert false 
    else:
      assert false


proc genFirstSet =
  for grammar in grammarSeq:
    if firstSet.hasKey(grammar.name):
      continue
    genFirstSet(grammar)


proc genFirstTokenSet = 
  for k, v in firstSet.pairs:
    let tokenSet = initSet[Token]()
    for str in v.items:
      #tokenSet.incl(strTokenMap[str])
      discard

proc parse(walker: GrammarWalker, token: string) = 
  discard


lexGrammar()

genFirstSet()

# maybe necessary or not... Currently not working
genFirstTokenSet()



when isMainModule:
  for grammar in grammarSeq:
    let name = grammar.name
    echo name
    #echo grammar.rootNode
    echo "    " & toSeq(firstSet[name].items).join(" ")

  
  var walker = newGrammarWalker("file_input")
  parse(walker, "NAME")
  echo walker.nodes

