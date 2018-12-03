import tables


proc getNew(): ref Table[string, int]
proc getNew2(): ref Table[string, int]


proc getNew(): ref Table[string, int] = 
  result = newTable[string, int]()
  for i in 0..1000:
    result.add($(i),  i)

proc getNew2(): ref Table[string, int] = 
  result = newTable[string, int]()
  for i in 2000..4000:
    result.add($(i),  i)
    var x = getNew()

while true:
  var t = getNew2()
  var y = getNew()

