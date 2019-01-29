class A:

    def __init__(self, x):
        self.x = x

    def __add__(self, y):
        return self.x + y

    def __len__(self):
        return 10

    def __iter__(self):
        return iter(range(10))

    def __str__(self):
        return "bla"


a = A(3)

assert a + 1 == 4
assert len(a) == 10

i = 0
for j in a:
    assert i == j
    i = i + 1

assert str(a) == "bla"

print("ok")
