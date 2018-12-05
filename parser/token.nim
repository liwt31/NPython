import macros
import tables
from strutils import splitLines
from parseutils import parseUntil


const
  grammarFileName = "Grammar"

  basicToken = @[
              ("ENDMARKER" , "Endmarker"),
              ("NAME"      , "Name"),
              ("NUMBER"    , "Number"),
              ("STRING"    , "String"),
              ("NEWLINE"   , "Newline"),
              ("INDENT"    , "Indent"),
              ("DEDENT"    , "Dedent"),
              ("("         , "Lpar"),
              (")"         , "Rpar"),
              ("["         , "Lsqb"),
              ("]"         , "Rsqb"),
              (":"         , "Colon"),
              (","         , "Comma"),
              (";"         , "Semi"),
              ("+"         , "Plus"),
              ("-"         , "Minus"),
              ("*"         , "Star"),
              ("/"         , "Slash"),
              ("|"         , "Vbar"),
              ("&"         , "Amper"),
              ("<"         , "Less"),
              (">"         , "Greater"),
              ("="         , "Equal"),
              ("."         , "Dot"),
              ("%"         , "Percent"),
              ("{"         , "Lbrace"),
              ("}"         , "Rbrace"),
              ("=="        , "Eqequal"),
              ("!="        , "Notequal"),
              ("<="        , "Lessequal"),
              (">="        , "Greaterequal"),
              ("~"         , "Tilde"),
              ("^"         , "Circumflex"),
              ("<<"        , "Leftshift"),
              (">>"        , "Rightshift"),
              ("**"        , "Doublestar"),
              ("+="        , "Plusequal"),
              ("-="        , "Minequal"),
              ("*="        , "Starequal"),
              ("/="        , "Slashequal"),
              ("%="        , "Percentequal"),
              ("&="        , "Amperequal"),
              ("|="        , "Vbarequal"),
              ("^="        , "Circumflexequal"),
              ("<<="       , "Leftshiftequal"),
              (">>="       , "Rightshiftequal"),
              ("**="       , "Doublestarequal"),
              ("//"        , "Doubleslash"),
              ("//="       , "Doubleslashequal"),
              ("@"         , "At"),
              ("@="        , "Atequal"),
              ("->"        , "Rarrow"),
              ("..."       , "Ellipsi")
  ]



proc readGrammarToken: seq[string] {.compileTime.} = 
  var textLines = slurp(grammarFileName).splitLines()
  for line in textLines:
    if line.len == 0:
      continue
    if line[0] in 'a'..'z':
      var tokenString: string
      discard line.parseUntil(tokenString, ':') # stoed in tokenString
      result.add(tokenString)
      

const grammarTokenList = readGrammarToken()


macro genTokenType(tokenTypeName, boundaryName: untyped): untyped = 
  result = newStmtList()
  var enumFields: seq[NimNode]
  for t in basicToken:
    enumFields.add(ident(t[1]))
  enumFields.add(boundaryName)
  for t in grammarTokenList:
    enumFields.add(ident(t))
  result.add(newEnum(
    name = tokenTypeName,
    fields = enumFields,
    public = true,
    pure = true
  ))


genTokenType(Token, boundary)


template genHelperFunc(tokenTypeName, boundaryName: untyped): untyped = 
  proc isTerminaltor*(node: tokenTypeName): bool = 
    node < tokenTypeName.boundaryName

  proc isNonTerminaltor*(node: tokenTypeName): bool = 
    tokenTypeName.boundaryName < node


genHelperFunc(Token, boundary)


macro genMapTable(tokenTypeName, tableName: untyped): untyped = 
  result = newStmtList()
  let tableNode = nnkTableConstr.newTree()
  for t in basicToken:
    let tokenNode = newDotExpr(tokenTypeName, ident(t[1]))
    tableNode.add(newColonExpr(newStrLitNode(t[0]), tokenNode))
  for t in grammarTokenList:
    let tokenNode = newDotExpr(tokenTypeName, ident(t))
    tableNode.add(newColonExpr(newStrLitNode(t), tokenNode))
    
  let dotNode = newDotExpr(tableNode, newIdentNode("newTable"))
  let letStmt = newLetStmt(tableName.postFix("*"), dotNode)
  result.add(letStmt)


genMapTable(Token, strTokenMap)

when isMainModule:
  echo strTokenMap
