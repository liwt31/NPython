import macros

import ../Objects/[pyobject, typeobject, dictobject, rangeobject,
                   stringobject, listobject, moduleobject, methodobject]
import ../Utils/utils

let bltinDict* = newPyDict()


proc registerBltinFunction(name: string, fun: BltinFunc) = 
  let nameStr = newPyString(name)
  bltinDict[nameStr] = newPyNimFunc(fun, nameStr)


macro implBltinFunc(prototype, pragmas, body: untyped): untyped = 
  var (methodName, argTypes) = getNameAndArgTypes(prototype)
  let name = ident("bltin" & $methodName)

  let procNode = newProc(
    nnkPostFix.newTree(
      ident("*"),  # let other modules call without having to lookup in the bltindict
      name,
    ),
    [
      ident("PyObject"), # return value
      nnkIdentDefs.newTree( # args in seq
        newIdentNode("args"),
        nnkBracketExpr.newTree(
          ident("seq"),
          ident("PyObject")
        ),
        nnkPrefix.newTree(
          ident("@"),
          nnkBracket.newTree()
        )
      )
    ],
    body, # the function body
  )
  # add pragmas, the last to add is the first to execute
  for p in pragmas:
    procNode.addPragma(p)

  procNode.addPragma(
    nnkExprColonExpr.newTree(
      ident("checkArgTypes"),
      nnkPar.newTree(
        methodName,
        argTypes
      ) 
    )
  )

  procNode.addPragma(ident("cdecl"))

  result = newStmtList(
    procNode,
    nnkCall.newTree(
      ident("registerBltinFunction"),
      newLit(methodName.strVal),
      name
    )
  )

# haven't think of how to deal with infinite num of args yet
# kwargs seems to be neccessary. So stay this way for now
# luckily it does not require much boilerplate
proc builtinPrint*(args: seq[PyObject]): PyObject {. cdecl .} =
  for obj in args:
    let objStr = obj.callMagic(str)
    errorIfNotString(objStr, "__str__")
    echo PyStrObject(objStr).str
  pyNone
registerBltinFunction("print", builtinPrint)

# this should be in the list constructor
#[
proc builtinList*(elms: seq[PyObject]): PyObject = 
  result = newPyList()
  for elm in elms:
    let retObj = result.appendPyListObject(@[elm])
    if retObj.isThrownException:
      return retObj
]#

implBltinFunc dir(obj: PyObject), []:
  # why in CPython 0 argument becomes `locals()`? no idea
  # get mapping proxy first then talk about how do deal with __dict__ of type
  var mergedDict = newPyDict()
  mergedDict.update(obj.getTypeDict)
  if obj.hasDict:
    mergedDict.update(PyDictObject(obj.getDict))
  mergedDict.keys


implBltinFunc type(obj: PyObject), []:
  obj.pyType


implBltinFunc len(obj: PyObject), []:
  obj.callMagic(len)


implBltinFunc iter(obj: PyObject), []:
  obj.callMagic(iter)



bltinDict[newPyString("range")] = pyRangeObjectType
bltinDict[newPyString("list")] = pyListObjectType
