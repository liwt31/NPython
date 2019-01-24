def foo(f):
    def bar():
        return 1
    return bar


@foo
@foo
def baz():
    return 2


assert baz() == 1


def foobar(i):
    def foo(f):
        def bar():
            return i
        return bar
    return foo


@foobar(10)
def baz():
    return 2


assert baz() == 10

print("ok")
