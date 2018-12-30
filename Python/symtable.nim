import tables
import macros

import ast
import asdl
import ../Objects/stringobject
import ../Utils/utils

type
  # a very simple symbol table for now
  # a detailed implementation requires two passes before compilation
  # and deals with lots of syntax error
  # Now it's done during the compilation
  # because only local vairables are considered
  SymTableEntry* = ref object
    # the difference between names and localVars is subtle.
    # In runtime, py object in names are looked up in local
    # dict and global dict by string key. 
    # At least global dict can be modified dynamically. 
    # whereas py object in localVars are looked up in var
    # sequence, thus faster. localVar can't be made global
    # def foo(x):
    #   global x
    # will result in an error (in CPython)
    names: Table[PyStrObject, int]
    localVars: Table[PyStrObject, int]

proc newSymTableEntry*: SymTableEntry =
  result = new SymTableEntry
  result.names = initTable[PyStrObject, int]()
  result.localVars = initTable[PyStrObject, int]()

proc hasLocal*(ste: SymTableEntry, localName: PyStrObject): bool =
  ste.localVars.hasKey(localName)

proc addLocalVar*(ste: SymTableEntry, localName: AsdlIdentifier) =
  let nameStr = localName.value
  if not ste.localVars.hasKey(nameStr):
    ste.localVars[nameStr] = ste.localVars.len

proc localId*(ste: SymTableEntry, localName: PyStrObject): int =
  ste.localVars[localName]

proc nameId*(ste: SymTableEntry, nameStr: PyStrObject): int =
  if ste.names.hasKey(nameStr):
    return ste.names[nameStr]
  else:
    let newId = ste.names.len
    ste.names[nameStr] = newId
    return newId

proc toInverseSeq(t: Table[PyStrObject, int]): seq[PyStrObject] =
  result = newSeq[PyStrObject](t.len)
  for name, id in t:
    result[id] = name

proc namesToSeq*(ste: SymTableEntry): seq[PyStrObject] = 
  ste.names.toInverseSeq

proc localVarsToSeq*(ste: SymTableEntry): seq[PyStrObject] = 
  ste.localVars.toInverseSeq

# traverse the ast to collect local vars
# local vars can be defined in Name List Tuple and For
# currently we only have Name, so it's pretty simple. lot's of discard out there

macro visitMethod(astNodeName, funcDef: untyped): untyped =
  result = nnkMethodDef.newTree(
    ident("visit"),
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      newEmptyNode(),
      newIdentDefs(
        ident("ste"),
        ident("SymTableEntry")
    ),
      newIdentDefs(
        ident("astNode"),
        ident("Ast" & $astNodeName)
    )
  ),
    newEmptyNode(),
    newEmptyNode(),
    funcdef,
  )


template visitSeq(ste: SymTableEntry, s: untyped) =
  for astNode in s:
    ste.visit(astNode)

method visit(std: SymTableEntry, astNode: AstNodeBase) {.base.} = 
  echo astNode
  unreachable

# no need to worry about simple expression
method visit(std: SymTableEntry, astNode: AsdlExpr) = 
  discard

visitMethod FunctionDef:
  ste.addLocalVar(astNode.name)


visitMethod Return:
  discard


visitMethod Assign:
  assert astNode.targets.len == 1
  ste.visit(astNode.targets[0])


visitMethod For:
  ste.visit(astNode.target)

visitMethod While:
  # the test part seems doesn't matter
  assert astNode.orelse.len == 0
  ste.visitSeq(astNode.body)


visitMethod If:
  ste.visitSeq(astNode.body)
  ste.visitSeq(astNode.orelse)

visitMethod Expr:
  discard

visitMethod Pass:
  discard

visitMethod Name:
  if astNode.ctx of AstStore:
    ste.addLocalVar(astNode.id)


proc collectLocalVar*(ste: SymTableEntry, f: AstFunctionDef) = 
  let args = AstArguments(f.args).args
  for arg in args:
    assert arg of AstArg
    ste.addLocalVar(AstArg(arg).arg)
  ste.visitSeq(f.body)
