import os
import macros
import tables
import sequtils
import strutils
import typetraits
import strformat

import asdl
import ../Parser/[token, parser]
import ../Objects/[pyobject, intobject, boolobject, stringobject]


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
  # then we only need to take care of store (lhs of `=`)
  result.ctx = new AstLoad

proc newAstConstant(obj: PyObject): AstConstant = 
  result = new AstConstant
  result.value = new AsdlConstant 
  result.value.value = obj



proc newBinOp(left: AsdlExpr, op: AsdlOperator, right: AsdlExpr): AstBinOp =
  result = new AstBinOp
  result.left = left
  result.op  = op
  result.right = right

proc newUnaryOp(op: AsdlUnaryop, operand: AsdlExpr): AstUnaryOp = 
  result = new AstUnaryOp
  result.op = op
  result.operand = operand

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

proc astDelStmt(parseNode: ParseNode): AsdlStmt
proc astPassStmt(parseNode: ParseNode): AsdlStmt
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
    let child = paramSeq[i] # NimNode seems doesn't support slicing
    expectKind(child, nnkPar)
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
  assert false

method setStore(astNode: AstName) = 
  astnode.ctx = new AstStore



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
  
# funcdef  'def' NAME parameters ['->' test] ':' suite
ast funcdef, [AstFunctionDef]:
  result = new AstFunctionDef
  result.name = newIdentifier(parseNode.children[1].tokenNode.content)
  result.args = astParameters(parseNode.children[2])
  assert parseNode.children.len == 5 # no return type annotation
  result.body = astSuite(parseNode.children[^1])
  assert result != nil

# parameters  '(' [typedargslist] ')'
ast parameters, [AstArguments]:
  result = astTypedArgsList(parseNode.children[1])
  

#  typedargslist: (tfpdef ['=' test] (',' tfpdef ['=' test])* [',' [
#        '*' [tfpdef] (',' tfpdef ['=' test])* [',' ['**' tfpdef [',']]]
#      | '**' tfpdef [',']]]
#  | '*' [tfpdef] (',' tfpdef ['=' test])* [',' ['**' tfpdef [',']]]
#  | '**' tfpdef [','])
# 
# Just one tfpdef should be easy enough
ast typedargslist, [AstArguments]:
  assert parseNode.children.len == 1
  assert parseNode.children[0].tokenNode.token == Token.tfpdef
  result = new AstArguments
  result.args.add(astTfpdef(parseNode.children[0]))
  
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
  testlistStarExpr1.setStore
  node.targets.add(testlistStarExpr1) 
  assert node.targets.len == 1
  node.value = testlistStarExpr2
  result = node
  assert result != nil

  
#ast annassign:
#  discard
  
# testlist_star_expr  (test|star_expr) (',' (test|star_expr))* [',']
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
  assert false
  
ast continue_stmt, [AsdlStmt]:
  assert false

# return_stmt: 'return' [testlist]
ast return_stmt, [AsdlStmt]:
  let node = new AstReturn
  if parseNode.children.len == 0:
    return node
  node.value = astTestList(parseNode.children[1])
  result = node
  
ast yield_stmt, [AsdlStmt]:
  assert false
  
ast raise_stmt, [AsdlStmt]:
  assert false
  

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
  
# if_stmt  'if' test ':' suite ('elif' test ':' suite)* ['else' ':' suite]
ast if_stmt, [AstIf]:
  result = new AstIf
  result.test = astTest(parseNode.children[1])
  result.body = astSuite(parseNode.children[3])
  if parseNode.children.len == 4:  # simple if no else
    return
  assert parseNode.children.len == 7 # no elif
  result.orelse = astSuite(parseNode.children[^1])
  
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
  
# help expr, xor_expr, and_expr, shift_expr, arith_expr, term
template astForBinOp(childAstFunc: untyped) = 
  assert parseNode.children.len mod 2 == 1
  let firstChild = parseNode.children[0]
  let firstAstNode = childAstFunc(firstChild)
  result = firstAstNode
  for idx in 1..parseNode.children.len div 2:
    var op: AsdlOperator
    case parseNode.children[2 * idx - 1].tokenNode.token
    of Token.VBar:
      op = new AstBitOr
    of Token.Circumflex:
      op = new AstBitXor
    of Token.Amper:
      op = new AstBitAnd
    of Token.LeftShift:
      op = new AstLShift
    of Token.RightShift:
      op = new AstRShift
    of Token.Plus:
      op = new AstAdd
    of Token.Minus:
      op = new AstSub
    of Token.Star:
      op = new AstMult
    else:
      assert false

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
    assert child.tokenNode.token == Token.power
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
      assert false
    discard
  else:
    assert false
    
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
ast atom, [AsdlExpr]:
  assert parseNode.children.len == 1
  let child = parseNode.children[0]
  case child.tokenNode.token
  of Token.NAME:
    result = newAstName(child.tokenNode)
  of Token.NUMBER:
    let pyInt = newPyInt(child.tokenNode.content)
    result = newAstConstant(pyInt)
  of Token.True:
    result = newAstConstant(pyTrueObj)
  of Token.False:
    result = newAstConstant(pyFalseObj)
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
  
  ]#
# testlist: test (',' test)* [',']
ast testlist, [AsdlExpr]:
  if parseNode.children.len == 1:
    return ast_test(parseNode.children[0])
  assert false
  # below is valid but not implemented in the compiler
  # so cancel for now
  let node = new AstTuple
  for child in parseNode.children:
    if child.tokenNode.token == Token.Comma:
      continue
    node.elts.add astTest(child) 
  return node

  
#ast dictorsetmaker:
#  discard
#  
ast classdef, [AstClassDef]:
  assert false
  
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

proc ast*(input: TaintedString): AstModule = 
  let root = parse(input)
  #echo root
  astFileInput(root)

when isMainModule:
  let args = commandLineParams()
  if len(args) < 1:
    quit("No arg provided")
  let input = readFile(args[0])
  echo ast(input)

