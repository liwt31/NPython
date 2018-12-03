import strutils
import parseutils
import sequtils
import strformat
import sets
import tables

from token import strTokenMap, Token

type
  GrammarNode = ref object
    name: string
    children: seq[GrammarNode]

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


# Grammar of EBNF
# A -> B E H
# B -> C | D | a
# C -> '[' F ']'
# D -> '(' F ')'
# E -> + | * | \epsilon
# F -> A G
# G -> '|' A G | \epsilon
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
  stringSeq.add(grammerNode.name)
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
  result.children.add(matchB(grammar))
  result.children.add(matchE(grammar))
  result.children.add(matchH(grammar))


proc matchB(grammar: Grammar): GrammarNode = 
  result = newGrammarNode("B")
  case grammar.getChar()
  of '[':
    result.children.add(matchC(grammar))
  of '(':
    result.children.add(matchD(grammar))
  of '\'':
    inc(grammar.cursor)
    var prev = grammar.cursor
    while grammar.getChar != '\'':
      inc(grammar.cursor)
    inc(grammar.cursor)
    let substr = grammar.grammarString[prev..grammar.cursor-2]
    result.children.add(newGrammarNode(substr))
  else:
    let first = grammar.cursor
    while grammar.cursor < len(grammar.grammarString):
      let c = grammar.grammarString[grammar.cursor]
      if c in IdentStartChars:
        inc(grammar.cursor)
      else:
        break
    let substr = grammar.grammarString[first..<grammar.cursor]
    result.children.add(newGrammarNode(substr))


proc matchC(grammar: Grammar): GrammarNode =
  result = newGrammarNode("C")
  var c = grammar.getChar()
  case c
  of '[':
    inc(grammar.cursor)
  else:
    errorGrammar(grammar)
  result.children.add(matchF(grammar))
  c = grammar.getChar()
  case c
  of ']':
    inc(grammar.cursor)
  else:
    errorGrammar(grammar)


proc matchD(grammar: Grammar): GrammarNode = 
  result = newGrammarNode("D")
  case grammar.getChar()
  of '(':
    inc(grammar.cursor)
  else:
    errorGrammar(grammar)
  result.children.add(matchF(grammar))
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
  result.children.add(matchG(grammar))


proc matchG(grammar: Grammar): GrammarNode = 
  if grammar.exhausted:
    return
  result = newGrammarNode("G")
  case grammar.getChar
  of '|':
    inc(grammar.cursor)
    result.children.add(matchA(grammar))
    result.children.add(matchG(grammar))
  else:
    discard


proc matchH(grammar: Grammar): GrammarNode =
  result = newGrammarNode("H")
  if grammar.exhausted:
    return
  case grammar.getChar
  of IdentStartChars, '[', '(', '\'': # handcrafted FirstSet for A
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


proc addToFirstSet(key: string, value: string | HashSet[string]) = 
  if not firstSet.haskey(key):
    firstSet[key] = initSet[string]()
  firstSet[key].incl(value)


proc genFirstSet(grammar: Grammar) =
  var toVisit = @[grammar.rootNode]
  let
    name: string = grammar.name
  while 0 < toVisit.len:
    let curNode = toVisit.pop()
    if curNode == nil: 
      continue
    case curNode.name
    of "A":
      let firstChild = curNode.children[0]
      if firstChild.name == "B": # take care of optional bracket
        if firstChild.children[0].name == "C":
          toVisit.add(curNode.children[2])
      toVisit.add(firstChild)
    of "B":
      let child = curNode.children[0]
      case child.name
      of "C", "D":
        toVisit.add(child)
      else:
        if grammarNameSet.hasKey(child.name):
          let g = grammarNameSet[child.name]
          genFirstSet(g)
          addToFirstSet(grammar.name, firstSet[child.name])
        else:
          addToFirstSet(grammar.name, child.name)
    of "C":
      toVisit.add(curNode.children[0])
    of "D":
      toVisit.add(curNode.children[0])
    of "E":
      quit("Unexpected E")
    of "F":
      toVisit.add(curNode.children[0])
      toVisit.add(curNode.children[1])
    of "G":
      if len(curNode.children) != 0:
        toVisit.add(curNode.children[0])
        toVisit.add(curNode.children[1])
    of "H":
      if len(curNode.children) != 0:
        toVisit.add(curNode.children[0])
    else:
      quit(fmt"Unknwow name {grammar.name}")


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
    echo "   " & toSeq(firstSet[name].items).join(" ")

  
  var walker = newGrammarWalker("file_input")
  parse(walker, "NAME")
  echo walker.nodes

