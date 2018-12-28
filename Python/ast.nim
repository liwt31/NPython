import os
import macros
import tables
import sequtils
import strutils
import typetraits
import strformat

import asdl
import ../Parser/[token, parser]
import ../Objects/[pyobject, numobjects, boolobjectBase, stringobject]
import ../Utils/utils


# in principle only define constructor for ast node that 
# appears more than once. There are exceptions below,
# but it should be keeped since now.

proc newAstExpr(expr: AsdlExpr): AstExpr = 
  result = new AstExpr
  result.value = expr


proc newIdentifier*(value: string): AsdlIdentifier = 
  result = new AsdlIdentifier
  result.value = newPyString(value)


proc newAstName(tokenNode: TokenNode): AstName = 
  assert tokenNode.token in contentTokenSet
  result = new AstName
  result.id = newIdentifier(tokenNode.content)
  # start in load because it's most common, 
  # then we only need to take care of store (such as lhs of `=`)
  result.ctx = new AstLoad

proc newAstConstant(obj: PyObject): AstConstant = 
  result = new AstConstant
  result.value = new AsdlConstant 
  result.value.value = obj

proc newBoolOp(op: AsdlBoolop, values: seq[AsdlExpr]): AstBoolOp =
  new result
  result.op = op
  result.values = values

proc newBinOp(left: AsdlExpr, op: AsdlOperator, right: AsdlExpr): AstBinOp =
  new result
  result.left = left
  result.op = op
  result.right = right

proc newUnaryOp(op: AsdlUnaryop, operand: AsdlExpr): AstUnaryOp = 
  new result
  result.op = op
  result.operand = operand


proc newList(elts: seq[AsdlExpr]): AstList = 
  new result
  result.elts = elts


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
proc astRaiseStmt(parseNode: ParseNode): AsdlStmt

proc astImportStmt(parseNode: ParseNode): AsdlStmt
proc astGlobalStmt(parseNode: ParseNode): AsdlStmt
proc astNonlocalStmt(parseNode: ParseNode): AsdlStmt
proc astAssertStmt(parseNode: ParseNode): AsdlStmt

proc astCompoundStmt(parseNode: ParseNode): AsdlStmt
proc astAsyncStmt(parseNode: ParseNode): AsdlStmt
proc astIfStmt(parseNode: ParseNode): AstIf
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
proc astTestlistComp(parseNode: ParseNode): seq[AsdlExpr]
proc astTrailer(parseNode: ParseNode, leftExpr: AsdlExpr): AsdlExpr
proc astTestList(parseNode: ParseNode): AsdlExpr
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
  unreachable

method setStore(astNode: AstCall) = 
  raiseSyntaxError("Can't assign to a function")

method setStore(astNode: AstName) = 
  astnode.ctx = new AstStore

method setStore(astNode: AstAttribute) = 
  astnode.ctx = new AstStore


# single_input: NEWLINE | simple_stmt | compound_stmt NEWLINE
ast single_input, [AstInteractive]:
  result = new AstInteractive
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
  
# funcdef  'def' NAME parameters ['->' test] ':' suite
ast funcdef, [AstFunctionDef]:
  result = new AstFunctionDef
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
    result = new AstArguments
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
  new result
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
  result = new AstArg
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
    let node = new AstAssign
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
    let node = new AstAugAssign
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
  if not (parseNode.children.len == 1):
    raiseSyntaxError("Testlist with comma not supported")
  if not (parseNode.children[0].tokenNode.token == Token.test):
    raiseSyntaxError("Star expression not implemented")
  result = ast_test(parseNode.children[0])
  assert result != nil
  

# augassign: ('+=' | '-=' | '*=' | '@=' | '/=' | '%=' | '&=' | '|=' | '^=' |
#             '<<=' | '>>=' | '**=' | '//=')
ast augassign, [AsdlOperator]:
  raiseSyntaxError("Inplace operator not implemented")
  #[
  case parseNode.children[0].tokenNode.token
  of Token.PlusEqual:
    result = new AstAdd
  of Token.MinEqual:
    result = new AstSub
  else:
    assert false
  ]#
  
proc astDelStmt(parseNode: ParseNode): AsdlStmt = 
  discard
  
ast pass_stmt, [AstPass]:
  new result
  

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
  raiseSyntaxError("Break not implemented")
  
ast continue_stmt, [AsdlStmt]:
  raiseSyntaxError("Continue not implemented")

# return_stmt: 'return' [testlist]
ast return_stmt, [AsdlStmt]:
  let node = new AstReturn
  if parseNode.children.len == 0:
    return node
  node.value = astTestList(parseNode.children[1])
  result = node
  
ast yield_stmt, [AsdlStmt]:
  raiseSyntaxError("Yield not implemented")
  
ast raise_stmt, [AsdlStmt]:
  raiseSyntaxError("Raise not implemented")
  

proc astImportStmt(parseNode: ParseNode): AsdlStmt = 
  raiseSyntaxError("Import not implemented")
  
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
  
# if_stmt  'if' test ':' suite ('elif' test ':' suite)* ['else' ':' suite]
ast if_stmt, [AstIf]:
  result = new AstIf
  result.test = astTest(parseNode.children[1])
  result.body = astSuite(parseNode.children[3])
  if parseNode.children.len == 4:  # simple if no else
    return
  if not (parseNode.children.len == 7):
    raiseSyntaxError("elif not implemented")
  result.orelse = astSuite(parseNode.children[^1])
  
# while_stmt  'while' test ':' suite ['else' ':' suite]
ast while_stmt, [AstWhile]:
  result = new AstWhile
  result.test = astTest(parseNode.children[1])
  result.body = astSuite(parseNode.children[3])
  if not (parseNode.children.len == 4):
    raiseSyntaxError("Else clause in while not implemented")
  
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
    op = new AstAnd
  of Token.or:
    op = new AstOr
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
    result = newUnaryOp(new AstNot, astNotTest(parsenode.children[1]))
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
  of Token.GreaterEqual:
    result = new AstGtE
  of Token.LessEqual:
    result = new AstLtE
  of Token.NotEqual:
    result = new AstNotEq
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
      op = new AstAdd
    of Token.Minus:
      op = new AstSub
    of Token.Star:
      op = new AstMult
    of Token.Slash:
      op = new AstDiv
    of Token.Percent:
      op = new AstMod
    of Token.DoubleSlash:
      op = new AstFloorDiv
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
      result = newUnaryOp(new AstUAdd, factor)
    of Token.Minus:
      result = newUnaryOp(new AstUSub, factor)
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
    result = newBinOp(base, new AstPow, exp)
  
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
      raiseSyntaxError("() for tuple not implemented")
    of 3:
      let child = parseNode.children[1]
      case child.tokenNode.token
      of Token.yield_expr:
        raiseSyntaxError("Yield expression not implemented")
      of Token.testlist_comp:
        let testListComp = astTestlistComp(child)
        # no tuple, just things like (1 + 2) * 3
        if not (testListComp.len == 1):
          raiseSyntaxError("Tuple not implemented")
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

  else:
    raiseSyntaxError("None and ... not implemented")
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
    var callNode = new AstCall
    callNode.fun = leftExpr
    case parseNode.children.len
    of 2:
      result = callNode 
    of 3:
      result = astArglist(parseNode.children[1], callNode)
    else:
      unreachable
  of Token.Lsqb:
    raiseSyntaxError("subscript [] not implemented")
  of Token.Dot:
    let attr = new AstAttribute
    attr.value = leftExpr
    attr.attr = newIdentifier(parseNode.children[1].tokenNode.content)
    attr.ctx = new AstLoad
    result = attr
  else:
    unreachable
  
  #[]
ast subscriptlist:
  discard
  
ast subscript:
  discard
  
ast sliceop:
  discard
  
ast exprlist:
  discard
  
  ]#
# testlist: test (',' test)* [',']
ast testlist, [AsdlExpr]:
  if parseNode.children.len == 1:
    return ast_test(parseNode.children[0])
  raiseSyntaxError("Long testlist (with comma) not implemented")
  # below is valid but not implemented in the compiler
  # so cancel for now
  #[
  let node = new AstTuple
  for child in parseNode.children:
    if child.tokenNode.token == Token.Comma:
      continue
    node.elts.add astTest(child) 
  return node
  ]#

  
#ast dictorsetmaker:
#  discard
#  
ast classdef, [AstClassDef]:
  raiseSyntaxError("Class defination not implemented")
  
# arglist  argument (',' argument)*  [',']
#proc astArglist(parseNode: ParseNode, callNode: AstCall): AstCall = 
ast arglist, [AstCall, callNode: AstCall]:
  # currently assume `argument` only has simplest `test`, e.g.
  # print(1,3,4), so we can do this
  for child in parseNode.children: 
    if child.tokenNode.token == Token.argument:
      callNode.args.add(astArgument(child))
  result = callNode
  
# argument  ( test [comp_for] | test '=' test | '**' test | '*' test  )
ast argument, [AsdlExpr]:
  if not (parseNode.children.len == 1):
    raiseSyntaxError("Only simple identifiers for function argument")
  let child = parseNode.children[0]
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

