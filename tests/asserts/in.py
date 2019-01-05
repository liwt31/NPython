l = [1,2,3]
assert 1 in l
assert 5 not in l

d = {1:2}
assert 1 in d
assert 2 not in d
d[2] = d
assert 2 in d

print("ok")
