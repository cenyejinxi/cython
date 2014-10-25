#################### FromPyStructUtility ####################

cdef extern from *:
    ctypedef struct PyTypeObject:
        char* tp_name
    PyTypeObject *Py_TYPE(obj)
    bint PyMapping_Check(obj)
    object PyErr_Format(exc, const char *format, ...)

@cname("{{funcname}}")
cdef {{struct_name}} {{funcname}}(obj) except *:
    cdef {{struct_name}} result
    if not PyMapping_Check(obj):
        PyErr_Format(TypeError, b"Expected %.16s, got %.200s", b"a mapping", Py_TYPE(obj).tp_name)

    {{for member in var_entries:}}
    try:
        value = obj['{{member.name}}']
    except KeyError:
        raise ValueError("No value specified for struct attribute '{{member.name}}'")
    result.{{member.cname}} = value
    {{endfor}}
    return result


#################### cfunc.to_py ####################

@cname("{{cname}}")
cdef object {{cname}}({{return_type.ctype}} (*f)({{ ', '.join(arg.type_cname for arg in args) }}) {{except_clause}}):
    def wrap({{ ', '.join('{arg.ctype} {arg.name}'.format(arg=arg) for arg in args) }}):
        """wrap({{', '.join(('{arg.name}: {arg.type_displayname}'.format(arg=arg) if arg.type_displayname else arg.name) for arg in args)}}){{if return_type.type_displayname}} -> {{return_type.type_displayname}}{{endif}}"""
        {{'' if return_type.type.is_void else 'return '}}f({{ ', '.join(arg.name for arg in args) }})
    return wrap


#################### carray.from_py ####################

cdef extern from *:
    object PyErr_Format(exc, const char *format, ...)

@cname("{{cname}}")
cdef int {{cname}}(object o, {{base_type}} *v, Py_ssize_t length) except -1:
    cdef Py_ssize_t i = length
    try:
        i = len(o)
    except (TypeError, OverflowError):
        pass
    if i == length:
        for i, item in enumerate(o):
            if i >= length:
                break
            v[i] = item
        else:
            i += 1  # convert index to length
            if i == length:
                return 0

    PyErr_Format(
        IndexError,
        ("too many values found during array assignment, expected %zd"
         if i >= length else
         "not enough values found during array assignment, expected %zd, got %zd"),
        length, i)


#################### carray.to_py ####################

cdef extern from *:
    ctypedef struct PyObject
    PyObject* {{to_py_func}}({{base_type}}) except NULL

    tuple PyTuple_New(Py_ssize_t size)
    void PyTuple_SET_ITEM(object  p, Py_ssize_t pos, PyObject*  o)

    list PyList_New(Py_ssize_t size)
    void PyList_SET_ITEM(object  p, Py_ssize_t pos, PyObject*  o)


@cname("{{cname}}")
cdef inline list {{cname}}({{base_type}} *v, Py_ssize_t length):
    cdef size_t i
    l = PyList_New(length)
    for i in range(<size_t>length):
        PyList_SET_ITEM(l, i, {{to_py_func}}(v[i]))
    return l


@cname("{{to_tuple_cname}}")
cdef inline tuple {{to_tuple_cname}}({{base_type}} *v, Py_ssize_t length):
    cdef size_t i
    t = PyTuple_New(length)
    for i in range(<size_t>length):
        PyTuple_SET_ITEM(t, i, {{to_py_func}}(v[i]))
    return t
