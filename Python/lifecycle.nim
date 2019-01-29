import os
import ospaths

import coreconfig
# init bltinmodule
import bltinmodule
import ../Objects/[pyobject, typeobject]


proc pyInit*(args: seq[string]) = 
  for t in bltinTypes:
    t.typeReady

  if args.len == 0:
    pyConfig.path = os.getCurrentDir()
  else:
    pyConfig.filepath = joinPath(os.getCurrentDir(), args[0])
    pyConfig.filename = pyConfig.filepath.extractFilename()
    pyConfig.path = pyConfig.filepath.parentDir()
  when defined(debug):
    echo "Python path: " & pyConfig.path

  
