
def foo(x):
    print(-x)

def bar():
    foo(2)

def foobar(x,y):
    z = 2
    return x+y+2 / z

foo(1)
# some ccomment
bar()

print(foobar(1, 4))
