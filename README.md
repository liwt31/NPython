# NPython

(Subset of) Python programming language implemented in Nim, from compiler to the VM.

### Purpose
Just for fun and practice. Learn both Python and Nim.


### Status
Capable of:
* basic arithmetic calculations (+ - * / // ** % int float)
* flow control with `if else`, `while` and `for`
* basic function (closure) defination and call. Decorators.
* builtin print, dir, len, range, tuple, list, dict, exceptions
* list comprehension (no set or dict yet).
* basic import such as `import foo`. No alias, no `from`, etc
* indexing with `[]` with slice (can not store to slice yet).
* assert statement, raise exceptions, basic `try ... except XXXError ... `, with detailed traceback message.
* very primitive `class` defination. No inheritance, no metatype, etc
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
* more features on user defined class
* builtin decorators like `property`
* yield stmt

### Performance
Nim is claimed to be as fast as C, and indeed it is. According to some really primitive benchmarks (`spin.py` and `f_spin.py`), although NPython is currently 5x-10x slower than CPython 3.7, it is at least in some cases faster than CPython < 2.4. This is already a huge achievement considering the numerous optimizations out there in the CPython codebase and NPython is focused on quick prototyping and lefts many rooms for optimization. For comparison, [RustPython0.0.1](https://github.com/RustPython/RustPython) is 100x slower than CPython3.7 and uses 10x more memory.

Currently, the performance bottle necks are object allocation, seq accessing (compared with CPython direct memory accessing), along with the slow big int library. The object allocation and seq accessing issue are basically impossible to solve unless we do GC on our own just like CPython. 


### Drawbacks
NPython currently relies on GC of Nim. Frankly speaking it's not satisfactory. 
* The GC uses thread-local heap, makes threading impossible (for Python).
* The GC does not play well with manually managed memory, making certain optimizations difficult or impossible.
* The GC can not be shared between different dynamic libs, which means NPython can not import Nim extension.

If we manage memory manually, hopefully these drawbacks can be overcomed. Of course that's a huge sacrifice.


### License
Follow CPython license.
