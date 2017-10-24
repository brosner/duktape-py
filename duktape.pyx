cimport cduk
cimport cpython

import threading
import sys
from libc.stdio cimport printf


cdef cduk.duk_int_t _ref_map_next_id = 1


class Error(Exception):
    pass


cdef force_unicode(b):
    return b.decode("utf-8")


cdef smart_str(s):
    return s.encode("utf-8")


cdef duk_reraise(cduk.duk_context *ctx, cduk.duk_int_t rc):
    if rc:
        if cduk.duk_is_error(ctx, -1):
            cduk.duk_get_prop_string(ctx, -1, "stack")
            stack_trace = cduk.duk_safe_to_string(ctx, -1)
            cduk.duk_pop(ctx)
            raise Error(force_unicode(stack_trace))
        else:
            raise Error(force_unicode(cduk.duk_safe_to_string(ctx, -1)))


class PyFunc:

    def __init__(self, func, nargs):
        self.func = func
        self.nargs = nargs


cdef to_python_string(cduk.duk_context *ctx, cduk.duk_idx_t idx):
    cdef cduk.duk_size_t strlen
    cdef const char *buf = cduk.duk_get_lstring(ctx, idx, &strlen)
    return force_unicode(buf[:strlen])


cdef to_python_list(cduk.duk_context *ctx, cduk.duk_idx_t idx):
    ret = []
    for i in range(cduk.duk_get_length(ctx, idx)):
        cduk.duk_get_prop_index(ctx, idx, i)
        ret.append(to_python(ctx, -1))
        cduk.duk_pop(ctx)
    return ret


cdef to_python_dict(cduk.duk_context *ctx, cduk.duk_idx_t idx):
    ret = {}
    cduk.duk_enum(ctx, idx, cduk.DUK_ENUM_OWN_PROPERTIES_ONLY)
    while cduk.duk_next(ctx, idx, 1):
        ret[to_python(ctx, -2)] = to_python(ctx, -1)
        cduk.duk_pop_n(ctx, 2)
    cduk.duk_pop_n(ctx, 1)
    return ret


cdef to_python_func(cduk.duk_context *ctx, cduk.duk_idx_t idx):
    global _ref_map_next_id

    cdef cduk.duk_int_t _ref_id = _ref_map_next_id
    _ref_map_next_id += 1

    fidx = cduk.duk_normalize_index(ctx, idx)

    cduk.duk_push_global_stash(ctx)  # [ ... stash ]
    cduk.duk_get_prop_string(ctx, -1, "_ref_map")  # [ ... stash _ref_map ]
    cduk.duk_push_int(ctx, _ref_id)  # [ ... stash _ref_map id ]
    cduk.duk_dup(ctx, fidx)  # [ ... stash _ref_map id func ]
    cduk.duk_put_prop(ctx, -3)  # [ ... stash _ref_map ]
    cduk.duk_pop_n(ctx, 2)

    f = Func()
    f.ctx = ctx
    f._ref_id = _ref_id
    return f


cdef class Func:

    cdef cduk.duk_context *ctx
    cdef cduk.duk_int_t _ref_id

    def __call__(self, *args):
        ctx = self.ctx
        cduk.duk_push_global_stash(ctx)  # -> [ ... stash ]
        cduk.duk_get_prop_string(ctx, -1, "_ref_map")  # -> [ ... stash _ref_map ]
        cduk.duk_push_int(ctx, self._ref_id)  # -> [ ... stash _ref_map _ref_id ]
        cduk.duk_get_prop(ctx, -2)  # -> [ ... stash _ref_map func ]
        for arg in args:
            to_js(ctx, arg)
        duk_reraise(ctx, cduk.duk_pcall(ctx, len(args)))  # -> [ ... stash _ref_map retval ]
        ret = to_python(ctx, -1)
        cduk.duk_pop_n(ctx, 3)
        return ret


cdef to_python(cduk.duk_context *ctx, cduk.duk_idx_t idx):
    if cduk.duk_is_boolean(ctx, idx):
        return bool(cduk.duk_get_boolean(ctx, idx))
    elif cduk.duk_is_nan(ctx, idx):
        return float("nan")
    elif cduk.duk_is_null_or_undefined(ctx, idx):
        return None
    elif cduk.duk_is_number(ctx, idx):
        return float(cduk.duk_get_number(ctx, idx))
    elif cduk.duk_is_string(ctx, idx):
        return to_python_string(ctx, idx)
    elif cduk.duk_is_array(ctx, idx):
        return to_python_list(ctx, idx)
    elif cduk.duk_is_function(ctx, idx):
        return to_python_func(ctx, idx)
    elif cduk.duk_is_object(ctx, idx):
        return to_python_dict(ctx, idx)
    else:
        return 'unknown'
        # raise TypeError("not_coercible", cduk.duk_get_type(ctx, idx))


cdef cduk.duk_ret_t js_func_wrapper(cduk.duk_context *ctx):
    # [ args... ]
    cdef cduk.duk_int_t nargs
    cdef void *ptr

    cduk.duk_push_current_function(ctx)

    cduk.duk_get_prop_string(ctx, -1, "__duktape_cfunc_nargs__")
    nargs = cduk.duk_require_int(ctx, -1)
    cduk.duk_pop(ctx)

    cduk.duk_get_prop_string(ctx, -1, "__duktape_cfunc_pointer__")
    ptr = cduk.duk_require_pointer(ctx, -1)
    func = <object>ptr
    cduk.duk_pop(ctx)

    cduk.duk_pop(ctx)

    args = [to_python(ctx, idx) for idx in range(nargs)]
    to_js(ctx, func(*args))
    return 1


cdef cduk.duk_ret_t js_func_finalizer(cduk.duk_context *ctx):
    ptr = cduk.duk_get_heapptr(ctx, -1)
    func = <object>ptr
    cpython.Py_DECREF(func)
    return 0


cdef to_js_func(cduk.duk_context *ctx, pyfunc):
    func, nargs = pyfunc.func, pyfunc.nargs
    cpython.Py_INCREF(func)
    cduk.duk_push_c_function(ctx, js_func_wrapper, -1)  # [ ... js_func_wrapper ]
    cduk.duk_push_c_function(ctx, js_func_finalizer, -1)  # [ ... js_func_wrapper js_func_finalizer ]
    cduk.duk_set_finalizer(ctx, -2)  # [ ... js_func_wrapper ]
    cduk.duk_push_pointer(ctx, <void*>func)  # [ ... js_func_wrapper func ]
    cduk.duk_put_prop_string(ctx, -2, "__duktape_cfunc_pointer__")  # [ ... js_func_wrapper ]
    cduk.duk_push_number(ctx, nargs)  # [ ... js_func_wrapper nargs ]
    cduk.duk_put_prop_string(ctx, -2, "__duktape_cfunc_nargs__")   # [ ... js_func_wrapper ]


cdef to_js_array(cduk.duk_context *ctx, lst):
    cduk.duk_push_array(ctx)
    for i, value in enumerate(lst):
        to_js(ctx, value)
        cduk.duk_put_prop_index(ctx, -2, i)


cdef to_js_dict(cduk.duk_context *ctx, dct):
    cduk.duk_push_object(ctx)
    for key, value in dct.items():
        to_js(ctx, value)
        cduk.duk_put_prop_string(ctx, -2, smart_str(key))


cdef to_js(cduk.duk_context *ctx, value):
    if value is None:
        cduk.duk_push_null(ctx)
    elif isinstance(value, str):
        cduk.duk_push_lstring(ctx, smart_str(value), len(value))
    elif isinstance(value, bool):
        if value:
            cduk.duk_push_true(ctx)
        else:
            cduk.duk_push_false(ctx)
    elif isinstance(value, (list, tuple)):
        to_js_array(ctx, value)
    elif isinstance(value, PyFunc):
        to_js_func(ctx, value)
    elif isinstance(value, dict):
        to_js_dict(ctx, value)


cdef class Context:

    cdef cduk.duk_context *ctx

    def __cinit__(self):
        self.ctx = cduk.duk_create_heap_default()
        self.setup()

    def __dealloc__(self):
        if self.ctx:
            cduk.duk_destroy_heap(self.ctx)
            self.ctx = NULL

    def setup(self):
        cduk.duk_push_global_stash(self.ctx)
        cduk.duk_push_object(self.ctx)
        cduk.duk_put_prop_string(self.ctx, -2, "_ref_map")
        cduk.duk_pop(self.ctx)

    def __setitem__(self, key, value):
        to_js(self.ctx, value)
        cduk.duk_put_global_string(self.ctx, smart_str(key))

    def __getitem__(self, key):
        cduk.duk_get_global_string(self.ctx, smart_str(key))
        return to_python(self.ctx, -1)

    def execute(self, filename):
        cduk.fileio_push_file_string(self.ctx, smart_str(filename))
        duk_reraise(self.ctx, cduk.duk_peval(self.ctx))
        return to_python(self.ctx, -1)
