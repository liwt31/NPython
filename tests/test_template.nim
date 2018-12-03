proc echo1() = 
  echo 1

proc echo2() = 
  echo 2

template myecho(num) =
  `"echo"num`()

myecho(1)
myecho(2)
`e"ch"o 1`()
