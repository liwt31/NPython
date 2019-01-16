import pyobject
import baseBundle
import frameobject
import funcobject

import ../Python/neval


methodMacroTmpl(Function, "Function")
methodMacroTmpl(BoundMethod, "BoundMethod")


implFunctionMagic call:
  # todo: eliminate the nil
  let f = newPyFrame(self, args, nil)
  if f.isThrownException:
    return f
  PyFrameObject(f).evalFrame


implBoundMethodMagic call:
  # todo: eliminate the nil
  let f = newPyFrame(self.fun, @[self.self] & args, nil)
  if f.isThrownException:
    return f
  PyFrameObject(f).evalFrame
