"wrapper module for duktape"

cimport cduk
cimport cpython


def force_unicode(b):
    return b.decode("utf-8")


def smart_str(s):
    return s.encode("utf-8")


class DuktapeError(Exception):

    def __init__(self, name, message, file, line, stack):
        self.name = name
        self.message = message
        self.file = file
        self.line = line
        self.stack = stack

    def __str__(self):
        return "[{} {}:{}] {}".format(
            self.name,
            self.file,
            self.line,
            self.message,
        )

    def __repr__(self):
        return "<Duktape:{}>".format(str(self))


cdef getprop(cduk.duk_context *ctx, str prop):
    """
    get property from stack-top object, return as python string, leave stack clean
    """
    cduk.duk_get_prop_string(ctx, -1, smart_str(prop))
    cdef const char *res = cduk.duk_safe_to_string(ctx, -1)
    cduk.duk_pop(ctx)
    return force_unicode(res)


cdef duk_reraise(cduk.duk_context* ctx, int res):
    """
    for duktape meths that return nonzero to indicate trouble, convert the error object to python and raise it
    """
    if res:
        err = DuktapeError(
            *[
                getprop(ctx, prop)
                for prop in ("name", "message", "file", "line", "stack")
            ]
        )
        cduk.duk_pop(ctx)
        raise err


class DukType:
    """
    wrapper for integer types that provide extra information
    """
    # todo: add flags for array, function
    TYPES={
        0: "missing",  # this means invalid stack index
        1: "undefined",
        2: type(None),  # null
        3: bool,
        4: float,
        5: str,
        6: object,
    }

    def __init__(self, type_int):
        self.type_int = type_int

    def type(self):
        return self.TYPES.get(self.type_int)

    @classmethod
    def fromname(clas, name):
        raise NotImplementedError

    def __repr__(self):
        return "<DukType {!i} {}>".format(self.type_int, self.type())


# todo: think about using these (but make sure they evaluate to false)
class DukNull: "not used yet"
class DukUndefined: "not used yet"


cdef class DukWrappedObject:
    # todo: use this to wrap things that we don't know how to convert to a python object
    pass


cdef unsigned int PY_DUK_COMPILE_ARGS = 0


cdef get_list(cduk.duk_context *ctx, index=-1):
    """
    helper for get_helper()
    """
    a = []
    for i in range(cduk.duk_get_length(ctx, index)):
        cduk.duk_get_prop_index(ctx, index, i) # this puts the elt on the stack
        try:
            a.append(get_helper(ctx, -1))
        finally:
            cduk.duk_pop(ctx)
    return a


cdef get_dict(cduk.duk_context *ctx, index=-1):
    """
    helper for get_helper()
    """
    d = {}
    cduk.duk_enum(ctx, index, cduk.DUK_ENUM_OWN_PROPERTIES_ONLY)
    try:
        while cduk.duk_next(ctx, index, True):  # this pushes k & v onto the stack
            try:
                d[get_helper(ctx, -2)] = get_helper(ctx, -1)
            finally:
                cduk.duk_pop_n(ctx, 2)
    finally:
        cduk.duk_pop_n(ctx, 1)  # pop the enum
    return d


cdef get_string(cduk.duk_context *ctx, index=-1):
    """
    helper for get_helper()
    """
    cdef cduk.duk_size_t strlen
    cdef const char *buf = cduk.duk_get_lstring(ctx, index, &strlen)
    return force_unicode(buf[:strlen])  # docs claim this allows nulls http://docs.cython.org/src/tutorial/strings.html#passing-byte-strings


cdef get_helper(cduk.duk_context *ctx, index=-1):
    if cduk.duk_is_boolean(ctx, index):
        return bool(cduk.duk_get_boolean(ctx, index))
    elif cduk.duk_is_nan(ctx, index):
        return float('nan')
    elif cduk.duk_is_null_or_undefined(ctx, index):
        return None  # todo: see DukNull etc above
    elif cduk.duk_is_number(ctx, index):
        return cduk.duk_get_number(ctx, index)  # todo: is there an internal int value? if yes test for that
    elif cduk.duk_is_string(ctx, index):
        return get_string(ctx, index)
    elif cduk.duk_is_array(ctx, index):
        return get_list(ctx, index)
    elif cduk.duk_is_object(ctx, index):
        return get_dict(ctx, index)  # note: I think this ends up being a catch-all. yuck.
    else:
        raise TypeError("not_coercible", DukType(cduk.duk_get_type(ctx, index)))  # todo: return a wrapper instead. also, this never triggers because of the is_object test above


cdef push_dict(cduk.duk_context *ctx, d):
    """
    helper for push
    """
    cduk.duk_push_object(ctx)
    try:
        for k, v in d.items():
            if not isinstance(k, str):
                raise TypeError("k_not_str", type(k))
            push_helper(ctx,v)
            cduk.duk_put_prop_string(ctx, -2, smart_str(k))
    except TypeError:
        cduk.duk_pop(ctx)
        raise


cdef push_array(cduk.duk_context *ctx, a):
    """
    helper for push
    """
    cduk.duk_push_array(ctx)
    try:
        for i, x in enumerate(a):
            push_helper(ctx, x)
            cduk.duk_put_prop_index(ctx, -2, i)
    except TypeError:
        cduk.duk_pop(ctx)  # cleanup
        raise


cdef push_helper(cduk.duk_context *ctx, item):
    if isinstance(item, str):
        cduk.duk_push_lstring(ctx, smart_str(item), len(item))
    elif isinstance(item, unicode):
        raise NotImplementedError("todo: unicode")
    elif isinstance(item, bool):
        if item:
            cduk.duk_push_true(ctx)
        else:
            cduk.duk_push_false(ctx)
    elif isinstance(item, (int, float)):
        cduk.duk_push_number(ctx, <double>item)  # todo: separate ints
    elif isinstance(item, (list, tuple)):
        push_array(ctx, item)
    elif isinstance(item, dict):
        push_dict(ctx, item)
    elif item is None:
        cduk.duk_push_null(ctx)
    else:
        raise TypeError("cant_coerce_type", type(item))


cdef const char* PYDUK_FP="__duktape_cfunc_pointer__"
cdef const char* PYDUK_NARGS="__duktape_cfunc_nargs__"


cdef cduk.duk_ret_t callback_wrapper(cduk.duk_context* ctx):
    """
    this is used in push_func. it's the c function pointer that wraps the duktape external function callback
    """
    cduk.duk_push_current_function(ctx)
    # warning: this section dangerously assumes that the props (PDUK_FP and _NARGS) haven't been modified
    cduk.duk_get_prop_string(ctx, -1, PYDUK_FP)
    func = <object>cduk.duk_get_pointer(ctx, -1)
    cpython.Py_INCREF(func)  # warning: this never gets cleaned. does duktape have a global transformation callback that can be hooked?
    if not callable(func):
        return cduk.DUK_RET_TYPE_ERROR
    cduk.duk_pop(ctx)  # pop the pointer
    cduk.duk_get_prop_string(ctx, -1, PYDUK_NARGS)
    nargs = cduk.duk_get_int(ctx, -1)
    cduk.duk_pop_n(ctx, 2)  # pop nargs and current_function
    if nargs == cduk.DUK_VARARGS:
        nargs = cduk.duk_get_top(ctx)  # this works because the function is called inside a dedicated stack
    elif nargs < 0:
        return cduk.DUK_RET_RANGE_ERROR  # DukContext.push_func protects from this unless someone was tinkering
    args_tuple = tuple([get_helper(ctx, i) for i in range(nargs)])  # for some reason, taking the inner list out here breaks compilation
    cdef object retval = cpython.PyObject_Call(<object>func, args_tuple, <object>NULL)
    push_helper(ctx, retval)
    return 1  # todo: DUK_EXEC_SUCCESS=0. is this DUK_EXEC_ERROR? or the number of args returned, maybe. link to docs.


cdef class DukContext:

    cdef cduk.duk_context *ctx

    def __cinit__(self):
        self.ctx = cduk.duk_create_heap_default()

    def __dealloc__(self):
        if self.ctx:
            cduk.duk_destroy_heap(self.ctx)
            self.ctx = NULL

    def gc(self):
        """
        run garbage collector
        """
        cduk.duk_gc(self.ctx, 0)

    def __len__(self):
        """
        calls duk_get_top, which is confusingly named. the *index* of the top item is len(stack)-1 (or just -1)
        """
        return cduk.duk_get_top(self.ctx)

    def get_type(self, index=-1):
        """
        type of value (as DukType) at index (pass -1 for top)
        """
        return DukType(cduk.duk_get_type(self.ctx, index))

    def get(self, index=-1):
        """
        get whatever's at the top of the stack and return to python. fail if stack empty or object is not coercible/wrappable.
        """
        return get_helper(self.ctx, index)

    def call(self, *args):
        """
        stack top object must be callable. see also call_prop
        """
        if not cduk.duk_is_callable(self.ctx, -1):
            raise TypeError("stack_top:not_callable")
        top = len(self)
        try:
            list(map(self.push, args))
        except TypeError:
            cduk.duk_set_top(self.ctx, top)
            raise
        # todo: make sure it cleans the stack in error case
        duk_reraise(self.ctx, cduk.duk_pcall(self.ctx, len(args)))

    def tostring(self, index=-1):
        """
        return a string representation of the stack top object
        """
        return cduk.duk_safe_to_string(self.ctx, index)

    # object property manipulators
    def get_prop(self, arg):
        """
        key can be int (index lookup) or string (key lookup)
        """
        # todo: is int access necessary? should there be an array wrapper?
        if isinstance(arg, int):
            cduk.duk_get_prop_index(self.ctx, -1, arg)
        elif isinstance(arg, str):
            cduk.duk_get_prop_string(self.ctx, -1, smart_str(arg))
        else:
            raise TypeError("arg_type", type(arg))

    def set_prop(self, str prop):
        """
        sets obj[key] = thing if the end of the duktape stack is [obj, thing]
        """
        cduk.duk_put_prop_string(self.ctx, -2, smart_str(prop))

    def call_prop(self, str prop, tuple jsargs):
        """
        stack top should be a function. prop is the string name of the function. args must be a tuple, can be empty
        """
        old_top = len(self)
        try:
            self.push(prop)
            list(map(self.push,jsargs))
        except TypeError:
            cduk.duk_set_top(self.ctx, old_top)
            raise
        # todo: I'm assuming that it cleans the stack in case of an error. instead of assuming, test.
        duk_reraise(self.ctx, cduk.duk_pcall_prop(self.ctx, old_top-1, len(jsargs)))

    def construct(self, *args):
        """
        the type you're making (i.e. its constructor function) should be stack-top.
        """
        old_top = len(self)
        if not cduk.duk_is_function(self.ctx, -1): raise TypeError('not_function')
        try: list(map(self.push, args))
        except TypeError:
            cduk.duk_set_top(self.ctx, old_top)
            raise
        duk_reraise(self.ctx, cduk.duk_pnew(self.ctx, len(args)))

    # eval
    def eval_file(self, str path):
        """
        leaves a return value on the top of the stack
        """
        duk_reraise(self.ctx, cduk.duk_peval_file(self.ctx, smart_str(path)))

    def eval_string(self, basestring js):
        """
        leaves a return value on the top of the stack
        """
        duk_reraise(self.ctx, cduk.duk_peval_string(self.ctx, smart_str(js)))


    # compile
    # todo below: I think compile *doesn't* leave a ret val on the stack. otherwise why is it different from eval_*?
    def compile_file(self, str path):
        """
        leaves a return value on the top of the stack
        """
        duk_reraise(self.ctx, cduk.duk_pcompile_file(self.ctx, PY_DUK_COMPILE_ARGS, smart_str(path)))

    def compile_string(self, basestring js):
        """
        leaves a return value on the top of the stack
        """
        duk_reraise(self.ctx, cduk.duk_pcompile_string(self.ctx, PY_DUK_COMPILE_ARGS, smart_str(js)))

    # push/pop
    def push(self, item):
        """
        push python object to JS stack. TypeError if it's something we don't handle
        """
        push_helper(self.ctx, item)

    def push_undefined(self):
        """
        necessary because None gets coerced to null
        """
        cduk.duk_push_undefined(self.ctx)

    def push_func(self, f, nargs):
        """
        nargs -1 for varargs. WARNING this leaks memory (the function is INCREF'd forever)
        """
        if not callable(f):
            raise TypeError
        if not isinstance(nargs, int):
            raise TypeError
        if nargs < 0 and nargs != -1:
            raise ValueError("-1 is varargs, no other negatives allowed")
        cpython.Py_INCREF(f)  # warning: this is a memory leak. look in duktape docs for gc triggers
        cduk.duk_push_c_function(self.ctx, callback_wrapper, nargs)
        cduk.duk_push_pointer(self.ctx, <void*>f)
        cduk.duk_put_prop_string(self.ctx, -2, PYDUK_FP)
        self.push(nargs)
        cduk.duk_put_prop_string(self.ctx, -2, PYDUK_NARGS)

    def pop(self, n=1):
        """
        pop N elts from the stack. doesn't return them, just removes them
        """
        cduk.duk_pop_n(self.ctx, n)

    # globals
    def get_global(self, str name):
        """
        look something global up by name, drop it on the stack
        """
        cduk.duk_get_global_string(self.ctx, smart_str(name))

    def set_global(self, str name):
        """
        set name globally to the thing at the top of the stack
        """
        cduk.duk_put_global_string(self.ctx, smart_str(name))
