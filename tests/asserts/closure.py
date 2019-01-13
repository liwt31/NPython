def get_add(n):
    def add(x):
        return x + n
    return add


myadd = get_add(1)

assert 2 == myadd(1)


def foo():
    x = 1
    def bar(y):
        def baz():
            z = 1
            return x + y + z
        return baz
    return bar(1)


assert 3 == foo()()


def change():
    x = 1
    def bar():
        assert x == 2
    x = 2
    bar()

change()

print("ok")
