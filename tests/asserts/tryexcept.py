def main():
    try:
        assert False
    except:
        pass


def catch():
    try:
        assert False
    except AssertionError:
        pass

def nocatch():
    try:
        a
    except AssertionError:
        pass

def nested():
    try:
        a
    except:
        try:
            b
        except:
            c


main()


catch()


def get_name_error(fun):
    flag = False
    try:
        fun()
    except NameError:
        flag = True
    assert flag


get_name_error(nocatch)


print("nested exception with A B C means ok")


nested()


