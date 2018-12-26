import ../Objects/[pyobject, typeobject]

proc pyInit* = 
  for t in bltinTypes:
    t.typeReady
