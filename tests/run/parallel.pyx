# tag: run
# distutils: libraries = gomp
# distutils: extra_compile_args = -fopenmp

cimport cython.parallel
from cython.parallel import prange, threadid
from libc.stdlib cimport malloc, free

cdef extern from "Python.h":
    void PyEval_InitThreads()

PyEval_InitThreads()

cdef void print_int(int x) with gil:
    print x

#@cython.test_assert_path_exists(
#    "//ParallelWithBlockNode//ParallelRangeNode[@schedule = 'dynamic']",
#    "//GILStatNode[@state = 'nogil]//ParallelRangeNode")
def test_prange():
    """
    >>> test_prange()
    (9, 9, 45, 45)
    """
    cdef Py_ssize_t i, j, sum1 = 0, sum2 = 0

    with nogil, cython.parallel.parallel:
        for i in prange(10, schedule='dynamic'):
            sum1 += i

    for j in prange(10, nogil=True):
        sum2 += j

    return i, j, sum1, sum2

def test_descending_prange():
    """
    >>> test_descending_prange()
    5
    """
    cdef int i, start = 5, stop = -5, step = -2
    cdef int sum = 0

    for i in prange(start, stop, step, nogil=True):
        sum += i

    return sum

def test_nested_prange():
    """
    Reduction propagation is not (yet) supported.

    >>> test_nested_prange()
    50
    """
    cdef int i, j
    cdef int sum = 0

    for i in prange(5, nogil=True):
        for j in prange(5):
            sum += i

    # The value of sum is undefined here

    sum = 0

    for i in prange(5, nogil=True):
        for j in prange(5):
            sum += i
        sum += 0

    return sum

# threadsavailable test, disable this for now as it won't compile
#def test_parallel():
#    """
#    >>> test_parallel()
#    """
#    cdef int *buf = <int *> malloc(sizeof(int) * threadsavailable())
#
#    if buf == NULL:
#        raise MemoryError
#
#    with nogil, cython.parallel.parallel:
#        buf[threadid()] = threadid()
#
#    for i in range(threadsavailable()):
#        assert buf[i] == i
#
#    free(buf)

def test_unsigned_operands():
    """
    This test is disabled, as this currently does not work (neither does it
    for 'for i from x < i < y:'. I'm not sure we should strife to support 
    this, at least the C compiler gives a warning.

    test_unsigned_operands()
    10
    """
    cdef int i
    cdef int start = -5
    cdef unsigned int stop = 5
    cdef int step = 1

    cdef int steps_taken = 0

    for i in prange(start, stop, step, nogil=True):
        steps_taken += 1

    return steps_taken

def test_reassign_start_stop_step():
    """
    >>> test_reassign_start_stop_step()
    20
    """
    cdef int start = 0, stop = 10, step = 2
    cdef int i
    cdef int sum = 0

    for i in prange(start, stop, step, nogil=True):
        start = -2
        stop = 2
        step = 0

        sum += i

    return sum

def test_closure_parallel_privates():
    """
    >>> test_closure_parallel_privates()
    9 9
    45 45
    0 0 9 9
    """
    cdef int x

    def test_target():
        nonlocal x
        for x in prange(10, nogil=True):
            pass
        return x

    print test_target(), x

    def test_reduction():
        nonlocal x
        cdef int i

        x = 0
        for i in prange(10, nogil=True):
            x += i

        return x

    print test_reduction(), x

    def test_generator():
        nonlocal x
        cdef int i

        x = 0
        yield x
        x = 2

        for i in prange(10, nogil=True):
            x = i

        yield x

    g = test_generator()
    print g.next(), x, g.next(), x

