import xfail

assert True
def foo():
    assert False
xfail.xfail(foo, AssertionError)

print("ok")
