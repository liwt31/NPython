l = list(range(10))

assert l[::-1][0] == 9
assert l[1:5:2][1] == 3
for i in range(10):
    assert l[:][i] == i
assert id(l) != id(l[:])
assert len(l[:9:-1]) == 0
print("ok")
