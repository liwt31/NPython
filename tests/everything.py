l = []


def foo():
    for i in [1,2,3,4,5]:
        l.append(i ** i / (i + 2 * (i - 10)))

    for j in range(10):
        l.append(j * i)


def bar():
    i = 1
    while i != 10:
        i = i + 1
        foo()


if True and 1 and 3:
    bar()


if 0  or False:
    l.clear()


print(l)


b = []
b.append(b)
print(b)

import function

print(function.foobar(1,2))
