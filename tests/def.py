
def foo(x):
    print(-x)

def bar():
    foo(2)

def foobar(x,y):
    return x+y

foo(1)
# some ccomment
bar()

print(foobar(1, 4))
