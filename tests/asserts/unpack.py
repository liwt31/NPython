import xfail

x, y = 1, 2

assert x == 1

def foo():
    return True, False

t, f = foo()

assert t
assert not f

a, b, c, d = range(4)

assert a < d

def fail():
    x,y = range(1)

xfail.xfail(fail, ValueError)

print("ok")
