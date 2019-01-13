array = [13, 5, 6, 12, 1, 14, 3, 2, -2, 11, 8, 0, 9, 4, 10, -1]


def quicksort(array, start, end):
    if end - start < 1:
        return
    pivot = array[start]
    l = start
    r = end - 1
    while l < r:
        while l < r and pivot < array[r]:
            r = r - 1
        if l < r:
            array[l], array[r] = array[r], array[l]
            l = l + 1
        while l < r and array[l] < pivot:
            l = l + 1
        if l < r:
            array[l], array[r] = array[r], array[l]
            r = r - 1
    quicksort(array, start, l)
    quicksort(array, l+1, end)


quicksort(array, 0, len(array))

for i in range(1, len(array)):
    assert array[i-1] < array[i]

print("ok")
