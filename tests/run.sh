echo "tryexcept.py is expected to fail"
echo "fib.py and import.py (imports fib.py) are expected to be slow"
PYTHON=../Python/python
for fname in ./asserts/*.py; do
    echo $fname
    $PYTHON $fname
done
