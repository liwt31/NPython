import neval
import compile
import coreconfig
import traceback
import lifecycle
import ../Parser/[lexer, parser]
import ../Objects/bundle
import ../Utils/[utils, compat]

var finished = true
var rootCst: ParseNode
let lexerInst = newLexer("<stdin>")
var prevF: PyFrameObject

proc interactivePython(input: cstring): bool {. exportc .} =
  echo input
  if finished:
    rootCst = nil
    lexerInst.clearIndent
  else:
    assert (not rootCst.isNil)

  try:
    rootCst = parseWithState($input, lexerInst, Mode.Single, rootCst)
  except SyntaxError:
    let e = SyntaxError(getCurrentException())
    let excpObj = fromBltinSyntaxError(e, newPyStr("<stdin>"))
    excpObj.printTb
    finished = true
    return true

  if rootCst.isNil:
    return true
  finished = rootCst.finished
  if not finished:
    return false

  let compileRes = compile(rootCst, "<stdin>")
  if compileRes.isThrownException:
    PyExceptionObject(compileRes).printTb
    return true
  let co = PyCodeObject(compileRes)

  when defined(debug):
    echo co

  var globals: PyDictObject
  if prevF != nil:
    globals = prevF.globals
  else:
    globals = newPyDict()
  let fun = newPyFunc(newPyString("Bla"), co, globals)
  let f = newPyFrame(fun)
  var retObj = f.evalFrame
  if retObj.isThrownException:
    PyExceptionObject(retObj).printTb
  else:
    prevF = f
  true


# karax not working. gh-86
#[
include karax/prelude
import karax/kdom

proc createDom(): VNode =
  result = buildHtml(tdiv):
    tdiv(class="stream"):
      echo stream.len
      for line in stream:
        let (prompt, content) = line
        tdiv(class="line"):
          p(class="prompt"):
            if prompt.len == 0:
              text kstring" "
            else:
              text prompt
          p:
            text content
    tdiv(class="line editline"):
      p(class="prompt"):
        text prompt
      p(class="edit", contenteditable="true"):
        proc onKeydown(ev: Event, n: VNode) =
          if KeyboardEvent(ev).keyCode == 13:
            let input = n.dom.innerHTML
            echo input
            interactivePython($input)
            n.dom.innerHTML = kstring""
            ev.preventDefault

setRenderer createDom

]#
# init without arguments
pyInit(@[])
