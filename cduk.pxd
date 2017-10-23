cdef extern from "duktape_c/duk_config.h":
    ctypedef struct duk_context:
        pass
    ctypedef size_t duk_size_t
    ctypedef int duk_int_t
    ctypedef unsigned int duk_uint_t
    ctypedef int duk_small_int_t
    ctypedef duk_int_t duk_idx_t
    ctypedef duk_small_int_t duk_ret_t
    ctypedef duk_small_int_t duk_bool_t
    ctypedef double duk_double_t
    ctypedef duk_uint_t duk_uarridx_t

cdef extern from "duktape_c/duktape.h":
    ctypedef duk_ret_t (*duk_c_function)(duk_context *ctx)
    ctypedef void *(*duk_alloc_function) (void *udata, duk_size_t size)
    ctypedef void *(*duk_realloc_function) (void *udata, void *ptr, duk_size_t size)
    ctypedef void (*duk_free_function) (void *udata, void *ptr)
    ctypedef void (*duk_fatal_function) (void *udata, const char *msg)
    ctypedef struct duk_function_list_entry:
        const char *key
        duk_c_function value
        duk_idx_t nargs

    void duk_concat(duk_context *ctx, duk_idx_t count)
    void duk_destroy_heap(duk_context* ctx)
    void duk_dup(duk_context *ctx, duk_idx_t from_idx)
    void duk_enum(duk_context *ctx, duk_idx_t obj_idx, duk_uint_t enum_flags)
    duk_bool_t duk_get_boolean(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_get_global_string(duk_context *ctx, const char *key)
    duk_size_t duk_get_length(duk_context *ctx, duk_idx_t idx)
    duk_double_t duk_get_number(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_get_prop(duk_context *ctx, duk_idx_t obj_idx)
    duk_bool_t duk_get_prop_index(duk_context *ctx, duk_idx_t obj_idx, duk_uarridx_t arr_idx)
    duk_bool_t duk_get_prop_string(duk_context *ctx, duk_idx_t obj_idx, const char *key)
    duk_idx_t duk_get_top(duk_context *ctx)
    duk_int_t duk_get_type(duk_context *ctx, duk_idx_t idx)
    void duk_insert(duk_context *ctx, duk_idx_t to_idx)
    duk_bool_t duk_is_array(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_is_boolean(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_is_error(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_is_function(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_is_nan(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_is_null_or_undefined(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_is_number(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_is_object(duk_context *ctx, duk_idx_t idx)
    duk_bool_t duk_is_string(duk_context *ctx, duk_idx_t idx)
    void duk_join(duk_context *ctx, duk_idx_t count)
    duk_bool_t duk_next(duk_context *ctx, duk_idx_t enum_idx, duk_bool_t get_value)
    duk_idx_t duk_normalize_index(duk_context *ctx, duk_idx_t idx)
    duk_int_t duk_pcall(duk_context *ctx, duk_idx_t nargs)
    duk_int_t duk_pcompile(duk_context *ctx, duk_uint_t flags) # macro
    duk_int_t duk_peval(duk_context *ctx) # macro
    void duk_pop(duk_context *ctx)
    void duk_pop_n(duk_context *ctx, duk_idx_t count)
    duk_idx_t duk_push_array(duk_context *ctx)
    duk_idx_t duk_push_c_function(duk_context *ctx, duk_c_function func, duk_idx_t nargs)
    void duk_push_current_function(duk_context *ctx)
    void duk_push_false(duk_context *ctx)
    void duk_push_global_object(duk_context *ctx)
    void duk_push_global_stash(duk_context *ctx)
    void duk_push_heap_stash(duk_context *ctx)
    void duk_push_int(duk_context *ctx, duk_int_t val)
    void duk_push_null(duk_context *ctx)
    void duk_push_number(duk_context *ctx, duk_double_t val)
    duk_idx_t duk_push_object(duk_context *ctx)
    void duk_push_pointer(duk_context *ctx, void *p)
    duk_idx_t duk_push_thread(duk_context *ctx)
    void duk_push_true(duk_context *ctx)
    void duk_push_undefined(duk_context *ctx)
    void duk_put_function_list(duk_context *ctx, duk_idx_t obj_idx, const duk_function_list_entry *funcs)
    duk_bool_t duk_put_global_string(duk_context *ctx, const char *key)
    duk_bool_t duk_put_prop(duk_context *ctx, duk_idx_t obj_idx)
    duk_bool_t duk_put_prop_index(duk_context *ctx, duk_idx_t obj_idx, duk_uarridx_t arr_idx)
    duk_bool_t duk_put_prop_string(duk_context *ctx, duk_idx_t obj_idx, const char *key)
    duk_c_function duk_require_c_function(duk_context *ctx, duk_idx_t idx)
    void duk_require_function(duk_context *ctx, duk_idx_t idx)
    duk_int_t duk_require_int(duk_context *ctx, duk_idx_t idx)
    duk_double_t duk_require_number(duk_context *ctx, duk_idx_t idx)
    void duk_require_stack(duk_context *ctx, duk_idx_t extra)
    void duk_set_finalizer(duk_context *ctx, duk_idx_t idx)


cdef extern from "fileio.c":
    void fileio_push_file_string(duk_context *ctx, const char *filename)
