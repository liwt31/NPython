class A:
    def __init__(self):
        self.x = 1

    def foo(self, b):
        return self.x + b


a = A()
assert a.x == 1
assert a.foo(1) == 2
print("ok")
