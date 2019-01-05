a=1
b=2
c=3
d=True
flag = False
if a and b and c and d:
    flag = True
assert flag

flag = False
if (0 and False) or a:
    flag = True
assert flag

print("ok")
