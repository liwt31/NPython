a = True
t = (1, 2, 4, a)

assert t[1] == 2
assert len(t) == 4
assert t[::2][-1] == 4
assert len(()) == 0

print("ok")


