def xfail(fun, excp):
    flag = False
    try:
        fun()
    except excp:
        flag = True

    assert flag
