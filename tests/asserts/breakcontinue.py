def single():
    for i in range(10):
        if i == 5:
            break
    assert i == 5


def double():
    for i in range(10):
        for j in range(10):
            if i == j and j == 5:
                break
        if i == j:
            assert j == 5 or j == 9
    while 1:
        break
    assert i == 9

    while 0 < i:
        i = i - 1
        continue
        assert i == 0


single()


double()


print("ok")
