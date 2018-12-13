import macros
import tables
import sequtils
import strutils
import typetraits
import strformat

import parser/token
import parser/parser


macro genSimpleInherit(parent: untyped, children: varargs[untyped]): untyped = 
  result = nnkTypeSection.newTree()
  for child in children:
    let nn = nnkTypeDef.newTree(
      ident("Ast" & child.strVal), 
      newEmptyNode(),
      nnkRefTy.newTree(
       nnkObjectTy.newTree(
         newEmptyNode(),
         nnkOfInherit.newTree(parent),
         newEmptyNode()
       )
      )
    )
    result.add(nn)


type
  # don't see why use a totally different language (ASDL) just to
  # declare some types. OOP is much clearer and simpler.

  AstNodeBase = ref object of RootObj

  # Types start with "Asdl" name indicates a "symbol" in ASDL
  # builtin types
  AsdlIdentifier = ref object of AstNodeBase
    value: string

  AsdlMod = ref object of AstNodeBase

  AsdlStmt = ref object of AstNodeBase
    lineno, colOffset: int

  AsdlExpr = ref object of AstNodeBase
    lineno, colOffset: int
  
  AsdlExprContext = ref object of AstNodeBase

  AsdlSlice = ref object of AstNodeBase

  AsdlBoolop = ref object of AstNodeBase

  AsdlOperator = ref object of AstNodeBase

  AsdlUnaryop = ref object of AstNodeBase

  AsdlCmpop = ref object of AstNodeBase

  AsdlComprehension = ref object of AstNodeBase

  AsdlExcepthandler = ref object of AstNodeBase

  AsdlArguments = ref object of AstNodeBase

  AsdlArg = ref object of AstNodeBase

  AsdlKeyword = ref object of AstNodeBase

  AsdlAlias = ref object of AstNodeBase

  AsdlWithitem = ref object of AstNodeBase


  # camel "Ast" and camel name indicate a "terminator" in ASDL
  AstModule = ref object of AsdlMod
    body: seq[AsdlStmt]

  AstAssign = ref object of AsdlStmt
    targets: seq[AsdlExpr]
    value: AsdlExpr

  AstAugAssign = ref object of AsdlStmt
    target: AsdlExpr
    op: AsdlOperator
    value: AsdlExpr


  AstExpr = ref object of AsdlStmt
    value: AsdlExpr

  AstBinOp = ref object of AsdlExpr
    left: AsdlExpr
    op: AsdlOperator
    right: AsdlExpr


  AstCall = ref object of AsdlExpr
    fun: AsdlExpr # supposed to be func but func is an identifier
    args: seq[AsdlExpr]
    keywords: seq[AsdlKeyword]

  AstName = ref object of AsdlExpr
    id: AsdlIdentifier
    ctx: AsdlExprContext

  AstNum = ref object of AsdlExpr
    n: AsdlIdentifier


# `Ast` is added as prefix for every children
genSimpleInherit(AsdlExprContext, Load, Store, Del, AugLoad, AugStore, Param)

genSimpleInherit(AsdlOperator, Add, Sub) # not complete

const tab = "   "


proc indent(str: string, level=1): seq[string] = 
  var indent: string 
  for i in 0..<level:
    indent &= tab
  split(str, "\n").mapIt(indent & it)


method `$`(node: AstNodeBase): string {.base.} =
  assert false

method `$`(node: AstAdd): string = 
  "+"

method `$`(node: AstSub): string = 
  "-"

method `$`(node: AstNum): string = 
  $(node.n.value)


method `$`(node: AstName): string = 
  $(node.id.value)

method `$`(node: AstBinOp): string = 
  var stringSeq = @["BinOp " & $(node.op)]
  stringSeq.add(indent($(node.left)))
  stringSeq.add(indent($(node.right)))
  stringSeq.join("\n")


method `$`(node: AstExpr): string = 
  $(node.value)

method `$`(node: AstCall): string = 
  var stringSeq = @["Call"]
  stringSeq.add(indent($(node.fun)))
  if 0 < node.args.len:
    stringSeq.add(tab & "Args")
    for arg in node.args:
      stringSeq.add(indent($arg, 2))
  if 0 < node.keywords.len:
    stringSeq.add(tab & "Keywords")
    for kw in node.keywords:
      stringSeq.add(indent($kw, 2))
  stringSeq.join("\n")

method `$`(node: AstModule): string = 
  var stringSeq = @["Module"]
  for child in node.body:
    stringSeq &= indent($(child))
  stringSeq.join("\n")


method `$`(node: AstAssign): string = 
  var stringSeq = @["Assign"]
  stringSeq.add(tab & "Target")
  for target in node.targets:
    stringSeq.add(indent($(target), 2))
  stringSeq.add(tab & "value")
  stringSeq.add(indent($(node.value), 2))
  stringSeq.join("\n")


proc newAstExpr(expr: AsdlExpr): AstExpr = 
  result = new AstExpr
  result.value = expr

proc newAstName(tokenNode: TokenNode): AstName = 
  result = new AstName
  result.id = new AsdlIdentifier
  result.id.value = tokenNode.content

proc newAstNum(tokenNode: TokenNode): AstNum = 
  result = new AstNum
  result.n = new AsdlIdentifier
  result.n.value = tokenNode.content


proc newBinOp(left: AsdlExpr, op: AsdlOperator, right: AsdlExpr): AstBinOp =
  result = new AstBinOp
  result.left = left
  result.op  = op
  result.right = right


# base params AST for functions
# some AST may have more params, see getParamsAst
let paramsAst {.compileTime.} = @[
  nnkBracketExpr.newTree( # function return type
    ident("seq"),
    ident("AstNodeBase")
  ),  
  newIdentDefs( # function argument (and type)
    ident("parseNode"),
    ident("ParseNode")
    )
  ]

proc astStmt(parseNode: ParseNode): seq[AsdlStmt]
proc astSimpleStmt(parseNode: ParseNode): seq[AsdlStmt] 
proc astSmallStmt(parseNode: ParseNode): AsdlStmt
proc astExprStmt(parseNode: ParseNode): AsdlStmt
proc astTestlistStarExpr(parseNode: ParseNode): AsdlExpr

proc astDelStmt(parseNode: ParseNode): AsdlStmt
proc astPassStmt(parseNode: ParseNode): AsdlStmt
proc astFlowStmt(parseNode: ParseNode): AsdlStmt
proc astBreakStmt(parseNode: ParseNode): AsdlStmt
proc astContinueStmt(parseNode: ParseNode): AsdlStmt
proc astImportStmt(parseNode: ParseNode): AsdlStmt
proc astGlobalStmt(parseNode: ParseNode): AsdlStmt
proc astNonlocalStmt(parseNode: ParseNode): AsdlStmt
proc astAssertStmt(parseNode: ParseNode): AsdlStmt

proc astCompoundStmt(parseNode: ParseNode): AsdlStmt

proc astTest(parseNode: ParseNode): AsdlExpr
proc astOrTest(parseNode: ParseNode): AsdlExpr
proc astAndTest(parseNode: ParseNode): AsdlExpr
proc astNotTest(parseNode: ParseNode): AsdlExpr
proc astComparison(parseNode: ParseNode): AsdlExpr

proc astExpr(parseNode: ParseNode): AsdlExpr
proc astXorExpr(parseNode: ParseNode): AsdlExpr
proc astAndExpr(parseNode: ParseNode): AsdlExpr
proc astShiftExpr(parseNode: ParseNode): AsdlExpr
proc astArithExpr(parseNode: ParseNode): AsdlExpr
proc astTerm(parseNode: ParseNode): AsdlExpr
proc astFactor(parseNode: ParseNode): AsdlExpr
proc astPower(parseNode: ParseNode): AsdlExpr
proc astAtomExpr(parseNode: ParseNode): AsdlExpr
proc astAtom(parseNode: ParseNode): AsdlExpr
proc astTrailer(parseNode: ParseNode, leftExpr: AsdlExpr): AsdlExpr
proc astArglist(parseNode: ParseNode, callNode: AstCall): AstCall
proc astArgument(parseNode: ParseNode): AsdlExpr

# DSL to simplify function defination
macro ast(tokenName, funcDef: untyped): untyped = 
  #let initResult = newAssignment(ident("result"), newCall("newAstNode", 
  #  newDotExpr(ident("parseNode"), ident("tokenNode"))))
  #let funcBody = newStmtList(initResult, funcDef)
  result = newProc(ident(fmt"ast_{tokenName}"), paramsAst, funcDef)



#  build ast Node according to token of child
macro childAst(child, astNode: untyped, tokens: varargs[Token]): untyped = 
  result = nnkCaseStmt.newTree
  # the case condition `child.tokenNode.token`
  result.add(
    newDotExpr(
      newDotExpr(child, ident("tokenNode")),
      ident("token")
      )
  )
  # enter build AST node branch according to token
  for token in tokens:
    result.add(
      nnkOfBranch.newTree(
        newDotExpr(ident("Token"), token),
        newStmtList(
          newAssignment(
            astNode,
            newCall("ast" & $token, child)
          )
        )
      )
    )

  # the else `assert false`
  result.add(
    nnkElse.newTree(
      newStmtList(
        nnkCommand.newTree(
          ident("assert"),
          ident("false")
        )
      )
    )
  )
    


ast single_input:
  discard
  
# file_input: (NEWLINE | stmt)* ENDMARKER
proc astFileInput(parseNode: ParseNode): AstModule =  
  result = new AstModule
  for child in parseNode.children:
    if child.tokenNode.token == Token.stmt:
      result.body &= astStmt(child)

ast eval_input:
  discard
  
ast decorator:
  discard
  
ast decorators:
  discard
  
ast decorated:
  discard
  
ast async_funcdef:
  discard
  
ast funcdef:
  discard
  
ast parameters:
  discard
  
ast typedargslist:
  discard
  
ast tfpdef:
  discard
  
ast varargslist:
  discard
  
ast vfpdef:
  discard
  

# stmt  simple_stmt | compound_stmt
# simply return the child
# currently only have simple_stmt
proc astStmt(parseNode: ParseNode): seq[AsdlStmt] =
  let child = parseNode.children[0]
  case child.tokenNode.token
  of Token.simple_stmt:
    result = astSimpleStmt(child)
  of Token.compound_stmt:
    result.add(astCompoundStmt(child))
  else:
    assert false
  
  
# simple_stmt: small_stmt (';' small_stmt)* [';'] NEWLINE
proc astSimpleStmt(parseNode: ParseNode): seq[AsdlStmt] = 
  for child in parseNode.children:
    if child.tokenNode.token == Token.small_stmt:
      result.add(ast_small_stmt(child))
  
# small_stmt: (expr_stmt | del_stmt | pass_stmt | flow_stmt |
#              import_stmt | global_stmt | nonlocal_stmt | assert_stmt)
proc astSmallStmt(parseNode: ParseNode): AsdlStmt = 
  let child = parseNode.children[0]
  childAst(child, result, 
    expr_stmt,
    del_stmt,
    pass_stmt,
    flow_stmt,
    import_stmt,
    global_stmt,
    nonlocal_stmt,
    assert_stmt)
  
# expr_stmt: testlist_star_expr (annassign | augassign (yield_expr|testlist) |
#                      ('=' (yield_expr|testlist_star_expr))*)
proc astExprStmt(parseNode: ParseNode): AsdlStmt = 
  let testlistStarExpr1 = astTestlistStarExpr(parseNode.children[0])
  if parseNode.children.len == 1:
    return newAstExpr(testlistStarExpr1)
  # simple cases like `x=1`
  assert parseNode.children[1].tokenNode.token == Token.Equal
  assert parseNode.children.len == 3
  let testlistStarExpr2 = astTestlistStarExpr(parseNode.children[2])
  var node = new AstAssign
  node.targets.add(testlistStarExpr1) 
  assert node.targets.len == 1
  node.value = testlistStarExpr2
  node

  
ast annassign:
  discard
  
# testlist_star_expr  (test|star_expr) (',' (test|star_expr))* [',']
proc astTestlistStarExpr(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  assert parseNode.children[0].tokenNode.token == Token.test
  ast_test(parseNode.children[0])
  
ast augassign:
  discard
  
proc astDelStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
proc astPassStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  

proc astFlowStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
proc astBreakStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
proc astContinueStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
ast return_stmt:
  discard
  
ast yield_stmt:
  discard
  
ast raise_stmt:
  discard
  
proc astImportStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
ast import_name:
  discard
  
ast import_from:
  discard
  
ast import_as_name:
  discard
  
ast dotted_as_name:
  discard
  
ast import_as_names:
  discard
  
ast dotted_as_names:
  discard
  
ast dotted_name:
  discard
  
proc astGlobalStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
proc astNonlocalStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
proc astAssertStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
proc astCompoundStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
ast async_stmt:
  discard
  
ast if_stmt:
  discard
  
ast while_stmt:
  discard
  
ast for_stmt:
  discard
  
ast try_stmt:
  discard
  
ast with_stmt:
  discard
  
ast with_item:
  discard
  
ast except_clause:
  discard
  
ast suite:
  discard
  
# test  or_test ['if' or_test 'else' test] | lambdef
proc astTest(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.or_test
  astOrTest(child)
  
ast test_nocond:
  discard
  
ast lambdef:
  discard
  
ast lambdef_nocond:
  discard
  
# or_test  and_test ('or' and_test)*
proc astOrTest(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.and_test
  astAndTest(child)
  
# and_test  not_test ('and' not_test)*
proc astAndTest(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.not_test
  astNotTest(child)
  
# not_test 'not' not_test | comparison
proc astNotTest(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.comparison
  astComparison(child)
  
# comparison  expr (comp_op expr)*
proc astComparison(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.expr
  astExpr(child)
  
ast comp_op:
  discard
  
ast star_expr:
  discard
  
# expr  xor_expr ('|' xor_expr)*
proc astExpr(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.xor_expr
  astXorExpr(child)
  
# xor_expr  and_expr ('^' and_expr)*
proc astXorExpr(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.and_expr
  astAndExpr(child)
  
# and_expr  shift_expr ('&' shift_expr)*
proc astAndExpr(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.shift_expr
  astShiftExpr(child)
  
# shift_expr  arith_expr (('<<'|'>>') arith_expr)*
proc astShiftExpr(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.arith_expr
  astArithExpr(child)
  
# arith_expr  term (('+'|'-') term)*
proc astArithExpr(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len mod 2 == 1
  let firstChild = parseNode.children[0]
  let firstTerm = astTerm(firstChild)
  result = firstTerm
  for idx in 1..parseNode.children.len div 2:
    var op: AsdlOperator
    case parseNode.children[2 * idx - 1].tokenNode.token
    of Token.Plus:
      op = new AstAdd
    of Token.Minus:
      op = new AstSub
    else:
      assert false

    let secondChild = parseNode.children[2 * idx]
    let secondTerm = astTerm(secondChild)
    result = newBinOp(result, op, secondTerm)
  
# term  factor (('*'|'@'|'/'|'%'|'//') factor)*
proc astTerm(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.factor
  astFactor(child)
  
# factor  ('+'|'-'|'~') factor | power
proc astFactor(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.power
  astPower(child)
  
# power  atom_expr ['**' factor]
proc astPower(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.atom_expr
  astAtomExpr(child)
  
# atom_expr  ['await'] atom trailer*
proc astAtomExpr(parseNode: ParseNode): AsdlExpr = 
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.atom # await not implemented
  result = astAtom(child)
  if parseNode.children.len == 1:
    return
  for trailerChild in parseNode.children[1..^1]:
    result = astTrailer(trailerChild, result)
  
# atom: ('(' [yield_expr|testlist_comp] ')' |
#      '[' [testlist_comp] ']' |
#      '{' [dictorsetmaker] '}' |
#      NAME | NUMBER | STRING+ | '...' | 'None' | 'True' | 'False')
proc astAtom(parseNode: ParseNode): AsdlExpr = 
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  case child.tokenNode.token
  of Token.NAME:
    result = newAstName(child.tokenNode)
  of Token.NUMBER:
    result = newAstNum(child.tokenNode)
  else:
    assert false
  
ast testlist_comp:
  discard
  
# trailer  '(' [arglist] ')' | '[' subscriptlist ']' | '.' NAME
proc astTrailer(parseNode: ParseNode, leftExpr: AsdlExpr): AsdlExpr = 
  assert parseNode.children[0].tokenNode.token == Token.LPar # only function calls
  var callNode = new AstCall
  callNode.fun = leftExpr
  case parseNode.children.len
  of 2:
    result = callNode 
  of 3:
    result = astArglist(parseNode.children[1], callNode)
  else:
    assert false
  
ast subscriptlist:
  discard
  
ast subscript:
  discard
  
ast sliceop:
  discard
  
ast exprlist:
  discard
  
ast testlist:
  discard
  
ast dictorsetmaker:
  discard
  
ast classdef:
  discard
  
# arglist  argument (',' argument)*  [',']
proc astArglist(parseNode: ParseNode, callNode: AstCall): AstCall = 
  assert parseNode.children.len == 1
  callNode.args.add(astArgument(parseNode.children[0]))
  callNode
  
# argument  ( test [comp_for] | test '=' test | '**' test | '*' test  )
proc astArgument(parseNode: ParseNode): AsdlExpr =  
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.test
  return astTest(child)
  
ast comp_iter:
  discard
  
ast sync_comp_for:
  discard
  
ast comp_for:
  discard
  
ast comp_if:
  discard
  
ast encoding_decl:
  discard
  
ast yield_expr:
  discard
  
ast yield_arg:
  discard


when isMainModule:
  let root = parse("a=1\nb=2\nc=a+b\nprint(a+b)")
  #let root = parse("a=1\nb=2\nc=a+b\n")
  #let root = parse("a=1\nb=2\n")
  echo root
  let res = astFileInput(root)
  echo res

