def factorial(x):
    if x == 0:
        return 1
    return x * factorial(x-1)


assert factorial(10) == 3628800
print("ok")
