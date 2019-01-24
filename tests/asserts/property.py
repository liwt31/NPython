import xfail


class A:
    def __init__(self):
        self.x = 1

    @property
    def y(self):
        return self.x


a = A()
assert a.x == 1
assert a.y == 1


def foo():
    A.x


xfail.xfail(foo, AttributeError)


assert A.y.__get__(a) == 1


print("ok")
