import macros

type
  GrammarNode = ref object
    name: string
    children: seq[GrammarNode]

  Grammar = ref object
    name*: string
    grammarString: string
    rootNode: GrammarNode
    cursor: int

dumpTree:
  proc matchA(grammar: Grammar): GrammarNode  
  proc matchB(grammar: Grammar): GrammarNode  

proc matchA(grammar: Grammar): GrammarNode =
  new(result)

proc matchB(grammar: Grammar): GrammarNode  =
  new(result)


var g = new(Grammar)
discard matchA(g)
discard matchB(g)
