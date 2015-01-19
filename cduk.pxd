"cython defs for duktape"

cdef extern from "duktape_c/duktape.h":
  # typedefs
  ctypedef void duk_context
  ctypedef size_t duk_size_t
  ctypedef int duk_int_t
  ctypedef unsigned int duk_uint_t
  ctypedef duk_int_t duk_idx_t
  ctypedef int duk_small_int_t
  ctypedef duk_small_int_t duk_bool_t
  ctypedef double duk_double_t
  ctypedef duk_small_int_t duk_ret_t
  ctypedef duk_ret_t (*duk_c_function)(duk_context *ctx)
  ctypedef duk_uint_t duk_uarridx_t

  # macro values
  unsigned int DUK_ENUM_OWN_PROPERTIES_ONLY
  unsigned int DUK_RET_TYPE_ERROR
  unsigned int DUK_RET_RANGE_ERROR
  unsigned int DUK_RET_ERROR
  unsigned int DUK_VARARGS

  duk_context* duk_create_heap_default() # macro
  void duk_destroy_heap(duk_context* ctx)

  void duk_enum(duk_context *ctx, duk_idx_t obj_index, duk_uint_t enum_flags)
  duk_bool_t duk_next(duk_context *ctx, duk_idx_t enum_index, duk_bool_t get_value)
  void duk_gc(duk_context *ctx, duk_uint_t flags)

  duk_bool_t duk_get_boolean(duk_context *ctx, duk_idx_t index)
  duk_double_t duk_get_number(duk_context *ctx, duk_idx_t index)
  duk_int_t duk_get_int(duk_context *ctx, duk_idx_t index)
  duk_uint_t duk_get_uint(duk_context *ctx, duk_idx_t index)
  const char *duk_get_lstring(duk_context *ctx, duk_idx_t index, duk_size_t *out_len)
  void *duk_get_buffer(duk_context *ctx, duk_idx_t index, duk_size_t *out_size)
  void *duk_get_pointer(duk_context *ctx, duk_idx_t index)
  duk_c_function duk_get_c_function(duk_context *ctx, duk_idx_t index)
  duk_context *duk_get_context(duk_context *ctx, duk_idx_t index)
  duk_size_t duk_get_length(duk_context *ctx, duk_idx_t index)

  duk_bool_t duk_get_prop_string(duk_context *ctx, duk_idx_t obj_index, const char *key)
  duk_bool_t duk_get_prop_index(duk_context *ctx, duk_idx_t obj_index, duk_uarridx_t arr_index)
  
  duk_bool_t duk_get_global_string(duk_context *ctx, const char *key)
  duk_bool_t duk_put_global_string(duk_context *ctx, const char *key)

  duk_idx_t duk_get_top(duk_context *ctx)
  void duk_set_top(duk_context *ctx, duk_idx_t index)
  duk_int_t duk_get_type(duk_context *ctx, duk_idx_t index)

  # is_*
  duk_bool_t duk_is_undefined(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_null(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_null_or_undefined(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_boolean(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_number(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_nan(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_string(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_object(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_buffer(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_pointer(duk_context *ctx, duk_idx_t index)

  duk_bool_t duk_is_array(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_function(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_c_function(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_callable(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_ecmascript_function(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_bound_function(duk_context *ctx, duk_idx_t index)
  duk_bool_t duk_is_thread(duk_context *ctx, duk_idx_t index)
  
  duk_int_t duk_pcompile_file(duk_context* ctx, duk_uint_t flags, const char* path) # macro
  duk_int_t duk_pcompile_string(duk_context* ctx, duk_uint_t flags, const char* src) # macro
  duk_int_t duk_peval_file(duk_context* ctx, const char* path) # macro
  duk_int_t duk_peval_string(duk_context* ctx, const char* src) # macro
  
  void duk_pop(duk_context *ctx)
  void duk_pop_n(duk_context *ctx, duk_idx_t count)
  
  duk_idx_t duk_push_object(duk_context *ctx)
  duk_idx_t duk_push_array(duk_context *ctx)
  void duk_push_undefined(duk_context *ctx)
  void duk_push_null(duk_context *ctx)
  void duk_push_true(duk_context *ctx)
  void duk_push_false(duk_context *ctx)
  void duk_push_number(duk_context *ctx, duk_double_t val)
  void duk_push_nan(duk_context *ctx)
  void duk_push_int(duk_context *ctx, duk_int_t val)
  void duk_push_uint(duk_context *ctx, duk_uint_t val)
  const char *duk_push_lstring(duk_context *ctx, const char *str, duk_size_t len)
  duk_idx_t duk_push_c_function(duk_context *ctx, duk_c_function func, duk_idx_t nargs)
  void duk_push_pointer(duk_context *ctx, void *p)
  void duk_push_current_function(duk_context *ctx)
  
  duk_bool_t duk_put_prop_string(duk_context *ctx, duk_idx_t obj_index, const char *key)
  duk_bool_t duk_put_prop_index(duk_context *ctx, duk_idx_t obj_index, duk_uarridx_t arr_index)
  const char* duk_safe_to_string(duk_context* ctx, duk_idx_t index) # macro

  duk_int_t duk_pcall(duk_context *ctx, duk_idx_t nargs)
  duk_int_t duk_pcall_method(duk_context *ctx, duk_idx_t nargs)
  duk_int_t duk_pcall_prop(duk_context *ctx, duk_idx_t obj_index, duk_idx_t nargs)
  void duk_new(duk_context *ctx, duk_idx_t nargs)
