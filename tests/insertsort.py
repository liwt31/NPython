array = [13, 5, 6, 12, 1, 14, 3, 2, -2, 11, 8, 0, 9, 4, 10, -1]


for i in range(1, len(array)):
    j = i
    var = array[j]
    while j != 0 and var < array[j-1]:
        array[j] = array[j-1]
        j = j - 1
    array[j] = var

print(array)
