import os
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

  AstClassDef = ref object of AsdlStmt
    name: AsdlIdentifier
    bases: seq[AsdlExpr]
    keywords: seq[AsdlKeyword]
    body: seq[AsdlStmt]
    decoratorList: seq[AsdlExpr]

  AstAssign = ref object of AsdlStmt
    targets: seq[AsdlExpr]
    value: AsdlExpr

  AstAugAssign = ref object of AsdlStmt
    target: AsdlExpr
    op: AsdlOperator
    value: AsdlExpr

  AstWhile = ref object of AsdlStmt
    test: AsdlExpr
    body: seq[AsdlStmt]
    orelse: seq[AsdlStmt]

  AstExpr = ref object of AsdlStmt
    value: AsdlExpr

  AstBinOp = ref object of AsdlExpr
    left: AsdlExpr
    op: AsdlOperator
    right: AsdlExpr

  AstCompare = ref object of AsdlExpr
    left: AsdlExpr
    ops: seq[AsdlCmpop]
    comparators: seq[AsdlExpr]

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

genSimpleInherit(AsdlOperator, Add, Sub, Mult, Div, Mod, Pow) # not complete

genSimpleInherit(AsdlCmpop, Eq, NotEq, Lt, LtE, Gt, GtE, Is, IsNot, In, NotIn)

const tab = "   "


macro astRepr(name, code: untyped): untyped = 
  result = nnkMethodDef.newTree(
    nnkAccQuoted.newTree(ident("$")),
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      ident("string"),
      newIdentDefs(ident("node"), name)
    ),
    newEmptyNode(),
    newEmptyNode(),
    code
  )



proc indent(str: string, level=1): seq[string] = 
  var indent: string 
  for i in 0..<level:
    indent &= tab
  split(str, "\n").mapIt(indent & it)


method `$`(node: AstNodeBase): string {.base.} =
  "!!!DUMMY!!!"

astRepr AstAdd:
  "+"

astRepr AstSub:
  "-"

astRepr AstMult:
  "*"

astRepr AstDiv:
  "/"

astRepr AstMod:
  "%"

astRepr AstPow:
  "**"

astRepr AstLt:
  "<"

astRepr AstGt:
  ">"

astRepr AstNum:
  $(node.n.value)


astRepr AstName:
  $(node.id.value)

method `$`(node: AstBinOp): string = 
  var stringSeq = @["BinOp " & $(node.op)]
  stringSeq.add(indent($(node.left)))
  stringSeq.add(indent($(node.right)))
  stringSeq.join("\n")


method `$`(node: AstExpr): string = 
  $(node.value)

astRepr AstCompare:
  var stringSeq = @["Compare"]
  stringSeq.add(indent($node.left))
  for i in 0..<node.ops.len:
    stringSeq.add(indent($node.ops[i]))
    stringSeq.add(indent($node.comparators[i]))
  stringSeq.join("\n")

astRepr AstCall:
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

astRepr AstModule:
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

astRepr AstWhile:
  var stringSeq = @["While"]
  stringSeq.add(tab & "Test")
  stringSeq.add(tab & tab & $node.test)
  stringSeq.add(tab & "Body")
  for child in node.body:
    stringSeq.add(indent($child, 2))
  stringSeq.add(tab & "OrElse")
  for child in node.orelse:
    stringSeq.add(indent($child, 2))
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

proc astDecorated(parseNode: ParseNode): AsdlStmt
proc astFuncdef(parseNode: ParseNode): AsdlStmt

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
proc astAsyncStmt(parseNode: ParseNode): AsdlStmt
proc astIfStmt(parseNode: ParseNode): AsdlStmt
proc astWhileStmt(parseNode: ParseNode): AstWhile
proc astForStmt(parseNode: ParseNode): AsdlStmt
proc astTryStmt(parseNode: ParseNode): AsdlStmt
proc astWithStmt(parseNode: ParseNode): AsdlStmt
proc astSuite(parseNode: ParseNode): seq[AsdlStmt]

proc astTest(parseNode: ParseNode): AsdlExpr
proc astOrTest(parseNode: ParseNode): AsdlExpr
proc astAndTest(parseNode: ParseNode): AsdlExpr
proc astNotTest(parseNode: ParseNode): AsdlExpr
proc astComparison(parseNode: ParseNode): AsdlExpr
proc astCompOp(parseNode: ParseNode): AsdlCmpop

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
proc astClassDef(parseNode: ParseNode): AstClassDef
proc astArglist(parseNode: ParseNode, callNode: AstCall): AstCall
proc astArgument(parseNode: ParseNode): AsdlExpr




#[
# base params AST for functions
# some AST may have more params, see getParamsAst
let paramsAstBase {.compileTime.} = @[
  nnkBracketExpr.newTree( # function return type
    ident("seq"),
    ident("AstNodeBase")
  ),  
  newIdentDefs( # function argument (and type)
    ident("parseNode"),
    ident("ParseNode")
    )
  ]

]#


proc genParamsSeq(paramSeq: NimNode): seq[NimNode] {.compileTime.} = 
  expectKind(paramSeq, nnkBracket)
  assert 0 < paramSeq.len
  result.add(paramSeq[0])
  result.add(newIdentDefs(ident("parseNode"), ident("ParseNode")))
  for i in 1..<paramSeq.len:
    let child = paramSeq[i] # NimNode seems doesn't support slicing
    expectKind(child, nnkPar)
    assert child.len == 2
    result.add(newIdentDefs(child[0], child[1]))


proc genFuncDef(tokenIdent: NimNode, funcDef: NimNode): NimNode {.compileTime.} = 
  expectKind(funcDef, nnkStmtList)
  let assertType= nnkCommand.newTree(
    ident("assert"),
    nnkInfix.newTree(
      ident("=="),
      nnkDotExpr.newTree(
        nnkDotExpr.newTree(
          ident("parseNode"),
          ident("tokenNode"),
        ),
        ident("token")
      ),
      nnkDotExpr.newTree(
        ident("Token"),
        tokenIdent
      )
    )
  )


#[
  let assertNotNil= nnkCommand.newTree(
    ident("assert"),
    nnkInfix.newTree(
      ident("!="),
      ident("result"),
      newNilLit()
    )
  )
  result = newStmtList(assertType, funcDef, assertNotNil)
]#
  result = newStmtList(assertType, funcDef)

# DSL to simplify function defination
macro ast(tokenName, paramSeq, funcDef: untyped): untyped = 
  #let initResult = newAssignment(ident("result"), newCall("newAstNode", 
  #  newDotExpr(ident("parseNode"), ident("tokenNode"))))
  #let funcBody = newStmtList(initResult, funcDef)
  result = newProc(
    ident(fmt"ast_{tokenName}"), 
    genParamsSeq(paramSeq), 
    genFuncDef(tokenName, funcDef)
  )



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
    


#[
ast single_input:
  discard
]#
  
# file_input: (NEWLINE | stmt)* ENDMARKER
ast file_input, [AstModule]:
  result = new AstModule
  for child in parseNode.children:
    if child.tokenNode.token == Token.stmt:
      result.body &= astStmt(child)

#[
ast eval_input, []:
  discard
  
ast decorator:
  discard
  
ast decorators:
  discard
  
]#
ast decorated, [AsdlStmt]:
  discard
  
ast async_funcdef, [AsdlStmt]:
  discard
  
ast funcdef, [AsdlStmt]:
  discard

#[
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
]#
  

# stmt  simple_stmt | compound_stmt
# simply return the child
# currently only have simple_stmt
ast stmt, [seq[AsdlStmt]]:
  let child = parseNode.children[0]
  case child.tokenNode.token
  of Token.simple_stmt:
    result = astSimpleStmt(child)
  of Token.compound_stmt:
    result.add(astCompoundStmt(child))
  else:
    assert false
  assert 0 < result.len
  for child in result:
    assert child != nil
  
  
# simple_stmt: small_stmt (';' small_stmt)* [';'] NEWLINE
#proc astSimpleStmt(parseNode: ParseNode): seq[AsdlStmt] = 
ast simple_stmt, [seq[AsdlStmt]]:
  for child in parseNode.children:
    if child.tokenNode.token == Token.small_stmt:
      result.add(ast_small_stmt(child))
  assert 0 < result.len
  for child in result:
    assert child != nil
  
# small_stmt: (expr_stmt | del_stmt | pass_stmt | flow_stmt |
#              import_stmt | global_stmt | nonlocal_stmt | assert_stmt)
#proc astSmallStmt(parseNode: ParseNode): AsdlStmt = 
ast small_stmt, [AsdlStmt]:
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
  assert result != nil
  
# expr_stmt: testlist_star_expr (annassign | augassign (yield_expr|testlist) |
#                      ('=' (yield_expr|testlist_star_expr))*)
#proc astExprStmt(parseNode: ParseNode): AsdlStmt = 
ast expr_stmt, [AsdlStmt]:
  let testlistStarExpr1 = astTestlistStarExpr(parseNode.children[0])
  if parseNode.children.len == 1:
    result = newAstExpr(testlistStarExpr1)
    assert result != nil
    return
  # simple cases like `x=1`
  assert parseNode.children[1].tokenNode.token == Token.Equal
  assert parseNode.children.len == 3
  let testlistStarExpr2 = astTestlistStarExpr(parseNode.children[2])
  var node = new AstAssign
  node.targets.add(testlistStarExpr1) 
  assert node.targets.len == 1
  node.value = testlistStarExpr2
  result = node
  assert result != nil

  
#ast annassign:
#  discard
  
# testlist_star_expr  (test|star_expr) (',' (test|star_expr))* [',']
#proc astTestlistStarExpr(parseNode: ParseNode): AsdlExpr = 
ast testlist_star_expr, [AsdlExpr]:
  assert parseNode.children.len == 1
  assert parseNode.children[0].tokenNode.token == Token.test
  result = ast_test(parseNode.children[0])
  assert result != nil
  
#ast augassign:
#  discard
  
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
  
#[

ast return_stmt:
  discard
  
ast yield_stmt:
  discard
  
ast raise_stmt:
  discard
]#
  
proc astImportStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
  #[
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
  
  ]#
proc astGlobalStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
proc astNonlocalStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
proc astAssertStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
# compound_stmt  if_stmt | while_stmt | for_stmt | try_stmt | with_stmt | funcdef | classdef | decorated | async_stmt
ast compound_stmt, [AsdlStmt]:
  let child = parseNode.children[0]
  childAst(child, result, 
    if_stmt,
    while_stmt,
    for_stmt,
    try_stmt,
    with_stmt,
    funcdef,
    classdef,
    decorated,
    async_stmt
    )
  assert result != nil
  
ast async_stmt, [AsdlStmt]:
  discard
  
ast if_stmt, [AsdlStmt]:
  discard
  
# while_stmt  'while' test ':' suite ['else' ':' suite]
ast while_stmt, [AstWhile]:
  result = new AstWhile
  result.test = astTest(parseNode.children[1])
  result.body = astSuite(parseNode.children[3])
  assert parseNode.children.len == 4 # no else clause
  
ast for_stmt, [AsdlStmt]:
  discard
  
ast try_stmt, [AsdlStmt]:
  discard
  
ast with_stmt, [AsdlStmt]:
  discard
  
  #[
ast with_item:
  discard
  
ast except_clause:
  discard
  
  ]#

# suite  simple_stmt | NEWLINE INDENT stmt+ DEDENT
ast suite, [seq[AsdlStmt]]:
  case parseNode.children.len
  of 1:
    let child = parseNode.children[0]
    result = astSimpleStmt(child)
  else:
    for child in parseNode.children[2..^2]:
      result.add(astStmt(child))
  assert result.len != 0
  for child in result:
    assert child != nil
  
# test  or_test ['if' or_test 'else' test] | lambdef
#proc astTest(parseNode: ParseNode): AsdlExpr = 
ast test, [AsdlExpr]:
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.or_test
  result = astOrTest(child)
  assert result != nil
  
  #[]
ast test_nocond:
  discard
  
ast lambdef:
  discard
  
ast lambdef_nocond:
  discard
  
  ]#

# or_test  and_test ('or' and_test)*
ast or_test, [AsdlExpr]:
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.and_test
  result = astAndTest(child)
  assert result != nil
  
# and_test  not_test ('and' not_test)*
ast and_test, [AsdlExpr]:
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.not_test
  result = astNotTest(child)
  assert result != nil
  
# not_test 'not' not_test | comparison
ast not_test, [AsdlExpr]:
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.comparison
  result = astComparison(child)
  assert result != nil
  
# comparison  expr (comp_op expr)*
ast comparison, [AsdlExpr]:
  let expr1 = astExpr(parseNode.children[0])
  if parseNode.children.len == 1:
    result = expr1
    assert result != nil
    return
  assert parseNode.children.len == 3  # cases like a<b<c etc are NOT included
  let op = astCompOp(parseNode.children[1])
  let expr2 = astExpr(parseNode.children[2])
  let cmp = new AstCompare
  cmp.left = expr1
  cmp.ops.add(op)
  cmp.comparators.add(expr2)
  result = cmp
  assert result != nil

# comp_op  '<'|'>'|'=='|'>='|'<='|'<>'|'!='|'in'|'not' 'in'|'is'|'is' 'not'
ast comp_op, [AsdlCmpop]:
  let token = parseNode.children[0].tokenNode.token
  case token
  of Token.Less:
    result = new AstLt
  of Token.Greater:
    result = new AstGt
  of Token.Eqequal:
    result = new AstEq
  else:
    assert false
#  
#ast star_expr:
#  discard
  
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
  let child = parseNode.children[0]
  let base = astAtomExpr(child)
  if len(parseNode.children) == 1:
    result = base
  else:
    let exp = astFactor(parseNode.children[2])
    result = newBinOp(base, new AstPow, exp)
  
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
  
#ast testlist_comp:
#  discard
  
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
  
  #[]
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
  
  ]#
ast classdef, [AstClassDef]:
  discard
  
# arglist  argument (',' argument)*  [',']
#proc astArglist(parseNode: ParseNode, callNode: AstCall): AstCall = 
ast arglist, [AstCall, (callNode, AstCall)]:
  assert parseNode.children.len == 1
  callNode.args.add(astArgument(parseNode.children[0]))
  result = callNode
  assert result != nil
  
# argument  ( test [comp_for] | test '=' test | '**' test | '*' test  )
ast argument, [AsdlExpr]:
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  assert child.tokenNode.token == Token.test
  result = astTest(child)
  assert result != nil
  

#[
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
]#

proc ast(input: TaintedString): AstNodeBase = 
  let root = parse(input)
  astFileInput(root)

when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  echo ast(input)

