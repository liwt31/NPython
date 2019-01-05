# NPython

(Subset of) Python programming language implemented in Nim, from compiler to the VM.

### Purpose
Just for fun and practice. Learn both Python and Nim.


### Status
Capable of:
* basic arithmetic calculations (+ - * / // ** % int float)
* `if else`
* loop with `while` and `for`
* very basic function defination and call
* builtin print, list, dir, range, dict
* basic import such as `import foo`, no alias, no `from`, etc
* indexing with `[]` (no slicing for list).
* assert statement(useful for testing)
* interactive mode and file mode

Check out `./tests` to see more examples.


### How to use
```
git clone https://github.com/liwt31/NPython.git
cd NPython
nim c ./Python/python
./Python/python
```

### Todo
* user defined class
* try...except

### Performance
Nim is claimed to be as fast as C, and indeed it is. According to some really primitive benchmarks (`spin.py` and `f_spin.py`), although NPython is currently 5x-10x slower than CPython 3.7, it is at least in some cases faster than CPython < 2.4. This is already a huge achievement considering the numerous optimizations out there in the CPython codebase and NPython is focused on quick prototyping and left many rooms for optimization.
The majority of time spent is on object allocation along with the slow big int library. The object allocation issue is basically impossible to solve
unless we do GC on our own just like CPython. 


### Drawbacks
NPython currently rely on GC of Nim. Frankly speaking it's not satisfactory. 
* The GC uses thread-local heap, makes threading impossible (for Python).
* The GC does not play well with manually managed memory, making certain optimization difficult or impossible.
* The GC can not be shared between different dynamic libs, which means NPython can not import Nim extension.


### License
Follow CPython license.
