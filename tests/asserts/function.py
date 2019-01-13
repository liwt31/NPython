import xfail


def cmp(a, b):
    return a < b


assert cmp(1, 2)
assert not cmp(5, 1)


def more_arg():
    cmp(2, 1, 3)


xfail.xfail(more_arg, TypeError)


def less_arg():
    cmp()


xfail.xfail(less_arg, TypeError)

print("ok")
