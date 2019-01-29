class A:
    def __init__(self):
        self.x = 1

    def foo(self, b):
        return self.x + b


a = A()
assert a.x == 1
assert a.foo(1) == 2


def foo():
    x = 1

    class B:
        def __init__(self):
            self.x = x
    return B


assert foo()().x == 1


class C:
    def __init__(self, x):
        self.x = x

c = C(True)
assert c.x
print("ok")
