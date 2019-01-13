a = True
t = (1, 2, 4, a)

assert t[1] == 2
assert len(t) == 4
assert t[::2][-1] == 4
assert len(()) == 0

t = 1,
assert t[0] == 1

t = 3, 2
assert t[0] == 3
assert t[1] == 2


def foo():
    return 1, 2


assert foo() == (1, 2)

assert (1, 2) != [1, 2]

assert tuple([3, 4]) == (3, 4)

print("ok")
