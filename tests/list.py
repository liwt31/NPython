l = [1,3.01,2,3,4,5, 1]
print("init")
print(l)
print("append false")
l.append(False)
print(l)
print("count 1: ", l.count(1))
print("index 3: ", l.index(3))
l.insert(0, 0)
print("insert 0: ", l)
print("pop", l)
while True:
    l.pop()
    print(l)

