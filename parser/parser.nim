import strformat
import os
import strutils
import sequtils
import sets
import tables

import grammar
import lexer
import token
import utils/utils



type

  Mode {.pure.} = enum
    Single
    File
    Eval

  ParseStatus {.pure.} = enum
    Normal
    Finished
    Error

  ParseNode = ref object
    tokenNode: TokenNode
    children: seq[ParseNode] # children in the CST
    grammarNodeSeq: seq[GrammarNode]  # current state in NFA


proc newParseNode(tokenNode: TokenNode): ParseNode = 
  assert tokenNode.token.isTerminator
  new result
  result.tokenNode = tokenNode


proc newParseNode(tokenNode, firstToken: TokenNode): ParseNode =
  assert firstToken.token in grammarSet[tokenNode.token].firstSet
  new result
  result.tokenNode = tokenNode
  let gNode = grammarSet[tokenNode.token].rootNode
  var toAdd: ParseNode
  for child in gNode.epsilonSet:
    if child.matchToken(firstToken.token):
      result.grammarNodeSeq.add(child)
      if child.token.isTerminator:
        if toAdd == nil:
          toAdd = newParseNode(firstToken)
        else:
          assert toAdd.tokenNode.token == child.token
      else:
        if toAdd == nil:
          toAdd = newParseNode(newTokenNode(child.token), firstToken)
        else:
          assert toAdd.tokenNode.token == child.token
  assert toAdd != nil
  result.children.add(toAdd)

proc `$`(node: ParseNode): string = 
  if node.children.len == 0:
    return fmt"{node.tokenNode}"
  var stringSeq = @[$node.tokenNode]
  for child in node.children:
    stringSeq.add split($(child), "\n").mapIt("    " & it).join("\n")
  return stringSeq.join("\n")

# simulate NFA directly
proc applyToken(node: ParseNode, token: TokenNode): ParseStatus =  
  var gNodeSeq = node.grammarNodeSeq
  var newGnSeq : seq[GrammarNode]
  var thisLayer = false # ensures at most one parse node is added to node.children
  proc addNexts(gn: GrammarNode) = 
    for nextGn in gn.nextSet:
      if nextGn.matchToken(token.token):
        newGnSeq.add(nextGn)
        if nextGn == successGrammarNode:  
          continue  # no need to worry about adding child
        if thisLayer:
          # make sure they are the same token, otherwide beyond LL1
          assert node.children[^1].tokenNode.token == nextGn.token
        else:
          thisLayer = true
          if nextGn.token.isTerminator:
            node.children.add(newParseNode(token))
          else:
            node.children.add(newParseNode(newTokenNode(nextGn.token), token))
  # flags to make sure dive into child once for non-terminators
  var nonTerminatorTokenAppeared = false 
  var childStatus: ParseStatus   
  for gn in gNodeSeq:
    case gn.kind
    of 'a':
      if gn.token.isTerminator:
        addNexts(gn)
      else:
        if not nonTerminatorTokenAppeared: # only process once for non terminator
          childStatus = node.children[^1].applyToken(token)
          nonTerminatorTokenAppeared = true
        case childStatus
        of ParseStatus.Normal:
          newGnSeq.add(gn) # enter this grammar node in the next parsing
        of ParseStatus.Error: # do nothing, remove this grammar node
          discard
        of ParseStatus.Finished: # the child is unable to process this token
          addNexts(gn)
    of 's':
      discard # discard the previous success indeed..
    else:
      let msg = fmt"Grammar Node of {gn} has kind {gn.kind}"
      raise newException(InternalError, msg)

  if newGnSeq.len == 0:
    return ParseStatus.Error
  else:
    node.grammarNodeSeq = newGnSeq

  if node.grammarNodeSeq.len == 1 and node.grammarNodeSeq[0] == successGrammarNode:
    ParseStatus.Finished
  else:
    ParseStatus.Normal


proc parse(input: TaintedString, mode=Mode.File): ParseNode = 
  var tokenSeq = lexString(input)
  case mode
  of Mode.File:
    tokenSeq.add(newTokenNode(Token.Newline))
    tokenSeq.add(newTokenNode(Token.Endmarker))
  of Mode.Single:
    discard
  of Mode.Eval:
    tokenSeq.add(newTokenNode(Token.Endmarker))
  let firstToken = tokenSeq[0]
  #echo tokenSeq
  result = newParseNode(newTokenNode(Token.file_input), firstToken)
  for token in tokenSeq[1..^1]:
    echo result.applyToken(token)

when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  echo parse(input)
