def main():
    try:
        assert False
    except:
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


nested()


print("ok")
