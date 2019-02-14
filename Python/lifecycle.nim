import coreconfig
# init bltinmodule
import bltinmodule
import ../Objects/[pyobject, typeobject]
import ../Utils/compat

when not defined(js):
  import os
  import ospaths

proc pyInit*(args: seq[string]) = 
  for t in bltinTypes:
    t.typeReady

  when defined(js):
    discard
  else:
    if args.len == 0:
      pyConfig.path = os.getCurrentDir()
    else:
      pyConfig.filepath = joinPath(os.getCurrentDir(), args[0])
      pyConfig.filename = pyConfig.filepath.extractFilename()
      pyConfig.path = pyConfig.filepath.parentDir()
    when defined(debug):
      echo "Python path: " & pyConfig.path

  
