A = type("A", (), {"x":1})
a = A()
assert a.x == 1
a.y = 2
assert a.y == 2
print("ok")
