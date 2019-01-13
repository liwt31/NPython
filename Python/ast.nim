import os
import macros
import tables
import sequtils
import strutils
import typetraits
import strformat

import asdl
import ../Parser/[token, parser]
import ../Objects/[pyobject, noneobject, numobjects, boolobjectImpl, stringobjectImpl]
import ../Utils/utils


# in principle only define constructor for ast node that 
# appears more than once. There are exceptions below,
# but it should be keeped since now.

proc newAstExpr(expr: AsdlExpr): AstExpr = 
  result = newAstExpr()
  result.value = expr


proc newIdentifier*(value: string): AsdlIdentifier = 
  result = new AsdlIdentifier
  result.value = newPyString(value)


proc newAstName(tokenNode: TokenNode): AstName = 
  assert tokenNode.token in contentTokenSet
  result = newAstName()
  result.id = newIdentifier(tokenNode.content)
  # start in load because it's most common, 
  # then we only need to take care of store (such as lhs of `=`)
  result.ctx = newAstLoad()

proc newAstConstant(obj: PyObject): AstConstant = 
  result = newAstConstant()
  result.value = new AsdlConstant 
  result.value.value = obj

proc newBoolOp(op: AsdlBoolop, values: seq[AsdlExpr]): AstBoolOp =
  result = newAstBoolOp()
  result.op = op
  result.values = values

proc newBinOp(left: AsdlExpr, op: AsdlOperator, right: AsdlExpr): AstBinOp =
  result = newAstBinOp()
  result.left = left
  result.op = op
  result.right = right

proc newUnaryOp(op: AsdlUnaryop, operand: AsdlExpr): AstUnaryOp = 
  result = newAstUnaryOp()
  result.op = op
  result.operand = operand


proc newList(elts: seq[AsdlExpr]): AstList = 
  result = newAstList()
  result.elts = elts
  result.ctx = newAstLoad()

proc newTuple(elts: seq[AsdlExpr]): AstTuple = 
  result = newAstTuple()
  result.elts = elts
  result.ctx = newAstLoad()

proc astDecorated(parseNode: ParseNode): AsdlStmt
proc astFuncdef(parseNode: ParseNode): AstFunctionDef
proc astParameters(parseNode: ParseNode): AstArguments
proc astTypedArgsList(parseNode: ParseNode): AstArguments
proc astTfpdef(parseNode: ParseNode): AstArg

proc astStmt(parseNode: ParseNode): seq[AsdlStmt]
proc astSimpleStmt(parseNode: ParseNode): seq[AsdlStmt] 
proc astSmallStmt(parseNode: ParseNode): AsdlStmt
proc astExprStmt(parseNode: ParseNode): AsdlStmt
proc astTestlistStarExpr(parseNode: ParseNode): AsdlExpr
proc astAugAssign(parseNode: ParseNode): AsdlOperator

proc astDelStmt(parseNode: ParseNode): AsdlStmt
proc astPassStmt(parseNode: ParseNode): AstPass
proc astFlowStmt(parseNode: ParseNode): AsdlStmt
proc astBreakStmt(parseNode: ParseNode): AsdlStmt
proc astContinueStmt(parseNode: ParseNode): AsdlStmt
proc astReturnStmt(parseNode: ParseNode): AsdlStmt
proc astYieldStmt(parseNode: ParseNode): AsdlStmt
proc astRaiseStmt(parseNode: ParseNode): AstRaise

proc astImportStmt(parseNode: ParseNode): AsdlStmt
proc astImportName(parseNode: ParseNode): AsdlStmt
proc astDottedAsNames(parseNode: ParseNode): seq[AstAlias]
proc astDottedName(parseNode: ParseNode): AstAlias
proc astGlobalStmt(parseNode: ParseNode): AsdlStmt
proc astNonlocalStmt(parseNode: ParseNode): AsdlStmt
proc astAssertStmt(parseNode: ParseNode): AstAssert

proc astCompoundStmt(parseNode: ParseNode): AsdlStmt
proc astAsyncStmt(parseNode: ParseNode): AsdlStmt
proc astIfStmt(parseNode: ParseNode): AstIf
proc astWhileStmt(parseNode: ParseNode): AstWhile
proc astForStmt(parseNode: ParseNode): AsdlStmt
proc astTryStmt(parseNode: ParseNode): AstTry
proc astExceptClause(parseNode: ParseNode): AstExceptHandler
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
proc astTestlistComp(parseNode: ParseNode): seq[AsdlExpr]
proc astTrailer(parseNode: ParseNode, leftExpr: AsdlExpr): AsdlExpr
proc astSubscriptlist(parseNode: ParseNode): AsdlSlice
proc astSubscript(parseNode: ParseNode): AsdlSlice
proc astExprList(parseNode: ParseNode): AsdlExpr
proc astTestList(parseNode: ParseNode): AsdlExpr
proc astDictOrSetMaker(parseNode: ParseNode): AsdlExpr
proc astClassDef(parseNode: ParseNode): AstClassDef
proc astArglist(parseNode: ParseNode, callNode: AstCall): AstCall
proc astArgument(parseNode: ParseNode): AsdlExpr



proc genParamsSeq(paramSeq: NimNode): seq[NimNode] {.compileTime.} = 
  expectKind(paramSeq, nnkBracket)
  assert 0 < paramSeq.len
  result.add(paramSeq[0])
  result.add(newIdentDefs(ident("parseNode"), ident("ParseNode")))
  for i in 1..<paramSeq.len:
    let child = paramSeq[i] # seems NimNode doesn't support slicing
    expectKind(child, nnkExprColonExpr)
    assert child.len == 2
    result.add(newIdentDefs(child[0], child[1]))


proc genFuncDef(tokenIdent: NimNode, funcDef: NimNode): NimNode {.compileTime.} = 
  # add assert type check for the function
  expectKind(funcDef, nnkStmtList)
  let assertType = nnkCommand.newTree(
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

  result = newStmtList(assertType, funcDef)

# DSL to simplify function defination
# should use a pragma instead?
macro ast(tokenName, paramSeq, funcDef: untyped): untyped = 
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
    
method setStore(astNode: AstNodeBase) {.base.} = 
  echo astNode
  raiseSyntaxError("can't assign")

method setStore(astNode: AstName) = 
  astnode.ctx = newAstStore()


method setStore(astNode: AstAttribute) = 
  astnode.ctx = newAstStore()


method setStore(astNode: AstSubscript) = 
  astnode.ctx = newAstStore()

# single_input: NEWLINE | simple_stmt | compound_stmt NEWLINE
ast single_input, [AstInteractive]:
  result = newAstInteractive()
  let child = parseNode.children[0]
  case parseNode.children.len
  of 1:
    case child.tokenNode.token
    of Token.NEWLINE:
      discard
    of Token.simple_stmt:
      result.body = astSimpleStmt(child)
    else:
      unreachable
  of 2:
    result.body.add astCompoundStmt(child)
  else:
    unreachable
  
# file_input: (NEWLINE | stmt)* ENDMARKER
ast file_input, [AstModule]:
  result = newAstModule()
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
  
# funcdef  'def' NAME parameters ['->' test] ':' suite
ast funcdef, [AstFunctionDef]:
  result = newAstFunctionDef()
  result.name = newIdentifier(parseNode.children[1].tokenNode.content)
  result.args = astParameters(parseNode.children[2])
  if not (parseNode.children.len == 5): 
    raiseSyntaxError("Return type annotation not implemented")
  result.body = astSuite(parseNode.children[^1])
  assert result != nil

# parameters  '(' [typedargslist] ')'
ast parameters, [AstArguments]:
  case parseNode.children.len
  of 2:
    result = newAstArguments()
  of 3:
    result = astTypedArgsList(parseNode.children[1])
  else:
    unreachable
  

#  typedargslist: (tfpdef ['=' test] (',' tfpdef ['=' test])* [',' [
#        '*' [tfpdef] (',' tfpdef ['=' test])* [',' ['**' tfpdef [',']]]
#      | '**' tfpdef [',']]]
#  | '*' [tfpdef] (',' tfpdef ['=' test])* [',' ['**' tfpdef [',']]]
#  | '**' tfpdef [','])
# 
# Just one tfpdef should be easy enough
ast typedargslist, [AstArguments]:
  result = newAstArguments()
  for i in 0..<parseNode.children.len:
    let child = parseNode.children[i]
    if i mod 2 == 1:
      if not (child.tokenNode.token == Token.Comma):
        raiseSyntaxError("Only support simple function arguments like foo(a,b)")
    else:
      if not (child.tokenNode.token == Token.tfpdef):
        raiseSyntaxError("Only support simple function arguments like foo(a,b)")
      result.args.add(astTfpdef(child))
  
# tfpdef  NAME [':' test]
ast tfpdef, [AstArg]:
  result = newAstArg()
  result.arg = newIdentifier(parseNode.children[0].tokenNode.content)
  
#[
ast varargslist:
  discard
  
ast vfpdef:
  discard
]#
  

# stmt  simple_stmt | compound_stmt
# simply return the child
ast stmt, [seq[AsdlStmt]]:
  let child = parseNode.children[0]
  case child.tokenNode.token
  of Token.simple_stmt:
    result = astSimpleStmt(child)
  of Token.compound_stmt:
    result.add(astCompoundStmt(child))
  else:
    unreachable
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
ast expr_stmt, [AsdlStmt]:
  let testlistStarExpr1 = astTestlistStarExpr(parseNode.children[0])
  if parseNode.children.len == 1:
    result = newAstExpr(testlistStarExpr1)
    return
  
  case parseNode.children[1].tokenNode.token
  of Token.Equal: # simple cases like `x=1`
    if not (parseNode.children.len == 3):
      raiseSyntaxError("Only support simple assign like x=1")
    let testlistStarExpr2 = astTestlistStarExpr(parseNode.children[2])
    let node = newAstAssign()
    testlistStarExpr1.setStore
    node.targets.add(testlistStarExpr1) 
    if not (node.targets.len == 1):
      raiseSyntaxError("Assign to multiple target not supported")
    node.value = testlistStarExpr2
    result = node
  of Token.augassign: # `x += 1` like
    raiseSyntaxError("Inplace operation not implemented")
    #[
    assert parseNode.children.len == 3
    let op = astAugAssign(parseNode.children[1])
    let testlist2 = astTestlist(parseNode.children[2])
    let node = newAstAugAssign()
    node.target = testlistStarExpr1
    node.op = op
    node.value = testlist2
    result = node
    ]#
  else:
    raiseSyntaxError("Only support simple assignment like a=1")
  assert result != nil

  
#ast annassign:
#  discard
  
# testlist_star_expr  (test|star_expr) (',' (test|star_expr))* [',']
ast testlist_star_expr, [AsdlExpr]:
  var elms: seq[AsdlExpr]
  for i in 0..<((parseNode.children.len + 1) div 2):
    let child = parseNode.children[2 * i]
    if not (child.tokenNode.token == Token.test):
      raiseSyntaxError("Star expression not implemented")
    elms.add ast_test(child)
  if parseNode.children.len == 1:
    result = elms[0]
  else:
    result = newTuple(elms)
  assert result != nil
  

# augassign: ('+=' | '-=' | '*=' | '@=' | '/=' | '%=' | '&=' | '|=' | '^=' |
#             '<<=' | '>>=' | '**=' | '//=')
ast augassign, [AsdlOperator]:
  raiseSyntaxError("Inplace operator not implemented")
  #[
  case parseNode.children[0].tokenNode.token
  of Token.PlusEqual:
    result = newAstAdd()
  of Token.MinEqual:
    result = newAstSub()
  else:
    assert false
  ]#
  
proc astDelStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
ast pass_stmt, [AstPass]:
  result = newAstPass()
  

# flow_stmt: break_stmt | continue_stmt | return_stmt | raise_stmt | yield_stmt
ast flow_stmt, [AsdlStmt]:
  let child = parseNode.children[0]
  childAst(child, result, 
    break_stmt,
    continue_stmt,
    return_stmt,
    raise_stmt,
    yield_stmt
  )
  assert result != nil



ast break_stmt, [AsdlStmt]:
  newAstBreak()
  
ast continue_stmt, [AsdlStmt]:
  newAstContinue()

# return_stmt: 'return' [testlist]
ast return_stmt, [AsdlStmt]:
  let node = newAstReturn()
  if parseNode.children.len == 0:
    return node
  node.value = astTestList(parseNode.children[1])
  node
  
ast yield_stmt, [AsdlStmt]:
  raiseSyntaxError("Yield not implemented")
  
# raise_stmt: 'raise' [test ['from' test]]
ast raise_stmt, [AstRaise]:
  result = newAstRaise()
  case parseNode.children.len
  of 1:
    discard
  of 2:
    result.exc = astTest(parseNode.children[1])
  else:
    raiseSyntaxError("Fancy raise not implemented")
  


# import_stmt  import_name | import_from
ast import_stmt, [AsdlStmt]:
  let child = parseNode.children[0]
  case child.tokenNode.token 
  of Token.import_name:
    result = astImportName(child)
  of Token.import_from:
    raiseSyntaxError("Import from not implemented")
  else:
    unreachable("wrong import_stmt")

# import_name  'import' dotted_as_names
ast import_name, [AsdlStmt]:
  let node = newAstImport()
  for c in parseNode.children[1].astDottedAsNames:
    node.names.add c
  node
  
  #[
ast import_from:
  discard
  
ast import_as_name:
  discard
]#

# dotted_as_name  dotted_name ['as' NAME]
ast dotted_as_name, [AstAlias]:
  if parseNode.children.len != 1:
    raiseSyntaxError("import alias not implemented")
  parseNode.children[0].astDottedName
  
  
#ast import_as_names:
#  discard

  
# dotted_as_names  dotted_as_name (',' dotted_as_name)*
ast dotted_as_names, [seq[AstAlias]]:
  if parseNode.children.len != 1:
    raiseSyntaxError("import multiple modules in one line not implemented")
  result.add parseNode.children[0].astDottedAsName
  
# dotted_name  NAME ('.' NAME)*
ast dotted_name, [AstAlias]:
  if parseNode.children.len != 1:
    raiseSyntaxError("dotted import name not supported")
  result = newAstAlias()
  result.name = newIdentifier(parseNode.children[0].tokenNode.content)
  
proc astGlobalStmt(parseNode: ParseNode): AsdlStmt = 
  raiseSyntaxError("global stmt not implemented")
  
proc astNonlocalStmt(parseNode: ParseNode): AsdlStmt = 
  raiseSyntaxError("nonlocal stmt not implemented")
  
# assert_stmt  'assert' test [',' test]
ast assert_stmt, [AstAssert]:
  result = newAstAssert()
  result.test = astTest(parseNode.children[1])
  if parseNode.children.len == 4:
    result.msg = astTest(parseNode.children[3])
  
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
  
# if_stmt  'if' test ':' suite ('elif' test ':' suite)* ['else' ':' suite]
ast if_stmt, [AstIf]:
  result = newAstIf()
  result.test = astTest(parseNode.children[1])
  result.body = astSuite(parseNode.children[3])
  if parseNode.children.len == 4:  # simple if no else
    return
  if not (parseNode.children.len == 7):
    raiseSyntaxError("elif not implemented")
  result.orelse = astSuite(parseNode.children[^1])
  
# while_stmt  'while' test ':' suite ['else' ':' suite]
ast while_stmt, [AstWhile]:
  result = newAstWhile()
  result.test = astTest(parseNode.children[1])
  result.body = astSuite(parseNode.children[3])
  if not (parseNode.children.len == 4):
    raiseSyntaxError("Else clause in while not implemented")

# for_stmt  'for' exprlist 'in' testlist ':' suite ['else' ':' suite]
ast for_stmt, [AsdlStmt]:
  if not (parseNode.children.len == 6):
    raiseSyntaxError("for with else not implemented")
  let forNode = newAstFor()
  forNode.target = astExprList(parseNode.children[1])
  forNode.target.setStore
  forNode.iter = astTestlist(parseNode.children[3])
  forNode.body = astSuite(parseNode.children[5])
  result = forNode

#  try_stmt: ('try' ':' suite
#           ((except_clause ':' suite)+
#            ['else' ':' suite]
#            ['finally' ':' suite] |
#           'finally' ':' suite))
ast try_stmt, [AstTry]:
  result = newAstTry()
  result.body = astSuite(parseNode.children[2])
  for i in 1..((parseNode.children.len-1) div 3):
    let child1 = parseNode.children[i*3]
    if not (child1.tokenNode.token == Token.except_clause):
      raiseSyntaxError("else/finally in try not implemented")
    let handler = astExceptClause(child1)
    let child3 = parseNode.children[i*3+2]
    handler.body = astSuite(child3)
    result.handlers.add(handler)
  

ast with_stmt, [AsdlStmt]:
  raiseSyntaxError("with not implemented")
  
  #[
ast with_item:
  discard
  ]#

# except_clause: 'except' [test ['as' NAME]]
ast except_clause, [AstExceptHandler]:
  result = newAstExceptHandler()
  case parseNode.children.len
  of 1:
    return
  of 2:
    result.type = astTest(parseNode.children[1])
  else:
    raiseSyntaxError("'except' with name not implemented")
  

  

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
  if not (parseNode.children.len == 1):
    raiseSyntaxError("Inline if else not implemented")
  let child = parseNode.children[0]
  if not (child.tokenNode.token == Token.or_test):
    raiseSyntaxError("lambda not implemented")
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

# help and or
template astForBoolOp(childAstFunc: untyped) = 
  assert parseNode.children.len mod 2 == 1
  let firstChild = parseNode.children[0]
  let firstAstNode = childAstFunc(firstChild)
  if parseNode.children.len == 1:
    return firstAstNode
  let token = parseNode.children[1].tokenNode.token
  var op: AsdlBoolop
  case token
  of Token.and:
    op = newAstAnd()
  of Token.or:
    op = newAstOr()
  else:
    unreachable
  var nodeSeq = @[firstAstNode]
  for idx in 1..parseNode.children.len div 2:
    let nextChild = parseNode.children[2 * idx]
    let nextAstNode = childAstFunc(nextChild)
    nodeSeq.add(nextAstNode)
  result = newBoolOp(op, nodeSeq)

# or_test  and_test ('or' and_test)*
ast or_test, [AsdlExpr]:
  astForBoolOp(astAndTest)
  
# and_test  not_test ('and' not_test)*
ast and_test, [AsdlExpr]:
  astForBoolOp(astNotTest)
  
# not_test 'not' not_test | comparison
ast not_test, [AsdlExpr]:
  let child = parseNode.children[0]
  case child.tokenNode.token
  of Token.not:
    result = newUnaryOp(newAstNot(), astNotTest(parsenode.children[1]))
  of Token.comparison:
    result = astComparison(child)
  else:
    unreachable
  assert result != nil
  
# comparison  expr (comp_op expr)*
ast comparison, [AsdlExpr]:
  let expr1 = astExpr(parseNode.children[0])
  if parseNode.children.len == 1:
    result = expr1
    assert result != nil
    return
  if not (parseNode.children.len == 3):  # cases like a<b<c etc are NOT included
    raiseSyntaxError("Chained comparison not implemented")
  let op = astCompOp(parseNode.children[1])
  let expr2 = astExpr(parseNode.children[2])
  let cmp = newAstCompare()
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
    result = newAstLt()
  of Token.Greater:
    result = newAstGt()
  of Token.Eqequal:
    result = newAstEq()
  of Token.GreaterEqual:
    result = newAstGtE()
  of Token.LessEqual:
    result = newAstLtE()
  of Token.NotEqual:
    result = newAstNotEq()
  of Token.in:
    result = newAstIn()
  of Token.not:
    result = newAstNotIn()
  else:
    raiseSyntaxError(fmt"Complex comparison operation {token} not implemented")
#  
#ast star_expr:
#  discard
  
# help expr, xor_expr, and_expr, shift_expr, arith_expr, term
template astForBinOp(childAstFunc: untyped) = 
  assert parseNode.children.len mod 2 == 1
  let firstChild = parseNode.children[0]
  let firstAstNode = childAstFunc(firstChild)
  result = firstAstNode
  for idx in 1..parseNode.children.len div 2:
    var op: AsdlOperator
    let token = parseNode.children[2 * idx - 1].tokenNode.token
    case token
    of Token.Plus:
      op = newAstAdd()
    of Token.Minus:
      op = newAstSub()
    of Token.Star:
      op = newAstMult()
    of Token.Slash:
      op = newAstDiv()
    of Token.Percent:
      op = newAstMod()
    of Token.DoubleSlash:
      op = newAstFloorDiv()
    else:
      let msg = fmt"Complex binary operation not implemented: " & $token
      raiseSyntaxError(msg)

    let secondChild = parseNode.children[2 * idx]
    let secondAstNode = childAstFunc(secondChild)
    result = newBinOp(result, op, secondAstNode)


# expr  xor_expr ('|' xor_expr)*
ast expr, [AsdlExpr]:
  astForBinOp(astXorExpr)
  
# xor_expr  and_expr ('^' and_expr)*
ast xor_expr, [AsdlExpr]:
  astForBinOp(astAndExpr)
  
# and_expr  shift_expr ('&' shift_expr)*
ast and_expr, [AsdlExpr]:
  astForBinOp(astShiftExpr)
  
# shift_expr  arith_expr (('<<'|'>>') arith_expr)*
ast shift_expr, [AsdlExpr]:
  astForBinOp(astArithExpr)
  
# arith_expr  term (('+'|'-') term)*
ast arith_expr, [AsdlExpr]:
  astForBinOp(astTerm)
  
# term  factor (('*'|'@'|'/'|'%'|'//') factor)*
ast term, [AsdlExpr]:
  astForBinOp(astFactor)
  
# factor  ('+'|'-'|'~') factor | power
ast factor, [AsdlExpr]:
  case parseNode.children.len
  of 1:
    let child = parseNode.children[0]
    result = astPower(child)
  of 2:
    let child1 = parseNode.children[0]
    let factor = astFactor(parseNode.children[1])
    case child1.tokenNode.token
    of Token.Plus:
      result = newUnaryOp(newAstUAdd(), factor)
    of Token.Minus:
      result = newUnaryOp(newAstUSub(), factor)
    else:
      raiseSyntaxError("Unary ~ not implemented")
  else:
    unreachable
    
# power  atom_expr ['**' factor]
proc astPower(parseNode: ParseNode): AsdlExpr = 
  let child = parseNode.children[0]
  let base = astAtomExpr(child)
  if len(parseNode.children) == 1:
    result = base
  else:
    let exp = astFactor(parseNode.children[2])
    result = newBinOp(base, newAstPow(), exp)
  
# atom_expr  ['await'] atom trailer*
proc astAtomExpr(parseNode: ParseNode): AsdlExpr = 
  let child = parseNode.children[0]
  if not (child.tokenNode.token == Token.atom): # await not implemented
    raiseSyntaxError("Await not implemented")
  result = astAtom(child)
  if parseNode.children.len == 1:
    return
  for trailerChild in parseNode.children[1..^1]:
    result = astTrailer(trailerChild, result)
  
# atom: ('(' [yield_expr|testlist_comp] ')' |
#      '[' [testlist_comp] ']' |
#      '{' [dictorsetmaker] '}' |
#      NAME | NUMBER | STRING+ | '...' | 'None' | 'True' | 'False')
ast atom, [AsdlExpr]:
  let child1 = parseNode.children[0]
  case child1.tokenNode.token
  of Token.Lpar:
    case parseNode.children.len
    of 2:
      return newTuple(@[])
    of 3:
      let child = parseNode.children[1]
      case child.tokenNode.token
      of Token.yield_expr:
        raiseSyntaxError("Yield expression not implemented")
      of Token.testlist_comp:
        let testListComp = astTestlistComp(child)
        # no tuple, just things like (1 + 2) * 3
        if testListComp.len == 1:
          return testListComp[0]
        return newTuple(testListComp)
      else:
        unreachable   
    else:
      unreachable

  of Token.Lsqb:
    case parseNode.children.len
    of 2:
      result = newList(@[])
    of 3:
      result = newList(astTestlistComp(parseNode.children[1]))
    else:
      unreachable

  of Token.Lbrace:
    case parseNode.children.len
    of 2:
      result = newAstDict()
    of 3:
      result = astDictOrSetMaker(parseNode.children[1])
    else:
      unreachable # {} blocked in lexer

  of Token.NAME:
    result = newAstName(child1.tokenNode)

  of Token.NUMBER:
    # todo: float
    for c in child1.tokenNode.content:
      if not (c in '0'..'9'):
        let f = parseFloat(child1.tokenNode.content)
        let pyFloat = newPyFloat(f)
        result = newAstConstant(pyFloat)
        return
    let pyInt = newPyInt(child1.tokenNode.content)
    result = newAstConstant(pyInt)

  of Token.STRING:
    var strSeq: seq[string]
    for child in parseNode.children:
      strSeq.add(child.tokenNode.content)
    let pyString = newPyString(strSeq.join())
    result = newAstConstant(pyString)

  of Token.True:
    result = newAstConstant(pyTrueObj)

  of Token.False:
    result = newAstConstant(pyFalseObj)

  of Token.None:
    result = newAstConstant(pyNone)

  else:
    raiseSyntaxError("ellipsis not implemented")
  assert result != nil
  

# testlist_comp  (test|star_expr) ( comp_for | (',' (test|star_expr))* [','] )
# currently only used in atom
ast testlist_comp, [seq[AsdlExpr]]:
  let child1 = parseNode.children[0]
  if child1.tokenNode.token == Token.star_expr:
    raiseSyntaxError("Star expression not implemented")
  result.add astTest(child1)
  if parseNode.children.len == 1:
    return
  for child in parseNode.children[1..^1]:
    case child.tokenNode.token
    of Token.comp_for:
      raiseSyntaxError("Comprehension not implemented")
    of Token.Comma:
      discard
    of Token.test:
      result.add astTest(child)
    of Token.star_expr:
      raiseSyntaxError("Star expression not implemented")
    else:
      unreachable

  
# trailer  '(' [arglist] ')' | '[' subscriptlist ']' | '.' NAME
ast trailer, [AsdlExpr, leftExpr: AsdlExpr]:
  case parseNode.children[0].tokenNode.token
  of Token.Lpar:
    var callNode = newAstCall()
    callNode.fun = leftExpr
    case parseNode.children.len
    of 2:
      result = callNode 
    of 3:
      result = astArglist(parseNode.children[1], callNode)
    else:
      unreachable
  of Token.Lsqb:
    let sub = newAstSubscript()
    sub.value = leftExpr
    sub.slice = astSubscriptlist(parseNode.children[1])
    sub.ctx = newAstLoad()
    result = sub
  of Token.Dot:
    let attr = newAstAttribute()
    attr.value = leftExpr
    attr.attr = newIdentifier(parseNode.children[1].tokenNode.content)
    attr.ctx = newAstLoad()
    result = attr
  else:
    unreachable
  
# subscriptlist: subscript (',' subscript)* [',']
ast subscriptlist, [AsdlSlice]:
  if not parseNode.children.len == 1:
    raiseSyntaxError("subscript only support one index")
  parseNode.children[0].astSubscript
  
# subscript: test | [test] ':' [test] [sliceop]
# sliceop: ':' [test]
ast subscript, [AsdlSlice]:
  let child1 = parseNode.children[0]
  if (child1.tokenNode.token == Token.test) and parseNode.children.len == 1:
    let index = newAstIndex()
    index.value = astTest(child1)
    return index
  # slice
  let slice= newAstSlice()
  # lower
  var idx = 0
  var child = parseNode.children[idx]
  if child.tokenNode.token == Token.test:
    slice.lower = astTest(child)
    idx += 2
  else:
    assert child.tokenNode.token == Token.Colon
    inc idx
  if idx == parseNode.children.len:
    return slice
  # upper
  child = parseNode.children[idx]
  if child.tokenNode.token == Token.test:
    slice.upper = astTest(child)
    inc idx
  if idx == parseNode.children.len:
    return slice
  child = parseNode.children[idx]
  # step
  assert child.tokenNode.token == Token.sliceop
  if child.children.len == 2:
    slice.step = astTest(child.children[1])
  slice


# exprlist: (expr|star_expr) (',' (expr|star_expr))* [',']
# currently only used in for stmt, so assume only one child
ast exprlist, [AsdlExpr]:
  if not (parseNode.children.len == 1):
    raiseSyntaxError("unpacking in for loop not implemented")
  let child = parseNode.children[0]
  if not (child.tokenNode.token == Token.expr):
    raiseSyntaxError("unpacking in for loop not implemented")
  astExpr(child)
  
# testlist: test (',' test)* [',']
ast testlist, [AsdlExpr]:
  var elms: seq[AsdlExpr]
  for i in 0..<((parseNode.children.len + 1) div 2):
    let child = parseNode.children[2 * i]
    elms.add ast_test(child)
  if parseNode.children.len == 1:
    result = elms[0]
  else:
    result = newTuple(elms)
  assert result != nil


#   dictorsetmaker: ( ((test ':' test | '**' expr)
#                   (comp_for | (',' (test ':' test | '**' expr))* [','])) |
#                  ((test | star_expr)
#                   (comp_for | (',' (test | star_expr))* [','])) )
ast dictorsetmaker, [AsdlExpr]:
  let children = parseNode.children
  let d = newAstDict()
  for idx in 0..<((children.len+1) div 4):
    let i = idx * 4
    if children.len < i + 3:
      raiseSyntaxError("dict defination too complex (no set, no comprehension)")
    let c1 = children[i]
    if not (c1.tokenNode.token == Token.test):
      raiseSyntaxError("dict defination too complex (no set, no comprehension)")
    d.keys.add(astTest(c1))
    if not (children[i+1].tokenNode.token == Token.Colon):
      raiseSyntaxError("dict defination too complex (no set, no comprehension)")
    let c3 = children[i+2]
    if not (c3.tokenNode.token == Token.test):
      raiseSyntaxError("dict defination too complex (no set, no comprehension)")
    d.values.add(astTest(c3))
  result = d
  
ast classdef, [AstClassDef]:
  raiseSyntaxError("Class defination not implemented")
  
# arglist  argument (',' argument)*  [',']
ast arglist, [AstCall, callNode: AstCall]:
  # currently assume `argument` only has simplest `test`, e.g.
  # print(1,3,4), so we can do this
  for child in parseNode.children: 
    if child.tokenNode.token == Token.argument:
      callNode.args.add(astArgument(child))
  callNode
  
# argument  ( test [comp_for] | test '=' test | '**' test | '*' test  )
ast argument, [AsdlExpr]:
  if not (parseNode.children.len == 1):
    raiseSyntaxError("Only simple identifiers for function argument")
  let child = parseNode.children[0]
  result = astTest(child)
  assert result != nil
  


#[
#ast comp_iter:
#  discard
  

# sync_comp_for: 'for' exprlist 'in' or_test [comp_iter]
ast sync_comp_for, [AsdlExpr]:
  discard
  
# comp_for: ['async'] sync_comp_for
ast comp_for, [AsdlExpr]:
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

proc ast*(root: ParseNode): AsdlModl = 
  case root.tokenNode.token
  of Token.file_input:
    result = astFileInput(root)
  of Token.single_input:
    result = astSingleInput(root)
  of Token.eval_input:
    unreachable  # currently no eval mode
  else:
    unreachable
  when defined(debug):
    echo result

proc ast*(input: TaintedString): AsdlModl= 
  let root = parse(input)
  result = ast(root)

when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  echo ast(input)

