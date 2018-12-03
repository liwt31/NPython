import macros
import tables

var global = 0
var globalTable = initTable[string, ref set[char]]()


macro mtest(): untyped = 
  for i in 1..3:
    #inc(global)
    #echo global
    if globalTable.hasKey($(i)):
      continue
    globalTable.add($(i), new(set[char]))
    echo globalTable.len


mtest()


proc ptest() = 
  for i in 4..8:
    #inc(global)
    #echo global
    globalTable.add($(i), new(set[char]))
    echo globalTable.len


macro mptest(): untyped = 
  ptest()


ptest()

mptest()
