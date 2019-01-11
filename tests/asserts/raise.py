import xfail


def raise_name_error():
    raise NameError


def empty_raise():
    raise


def reraise():
    try:
        1//0
    except ZeroDivisionError:
        raise


xfail.xfail(raise_name_error, NameError)
xfail.xfail(empty_raise, RuntimeError)
xfail.xfail(reraise, ZeroDivisionError)


print("ok")
