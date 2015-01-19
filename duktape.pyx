"wrapper module for duktape"

cimport cduk

class DuktapeError(StandardError):
  def __init__(self, name, message, file, line, stack):
    self.name, self.message, self.file, self.line, self.stack = name, message, file, line, stack
  def __repr__(self): return '<Duktape:%s %s:%s "%s">'%(self.name, self.file, self.line, self.message)

cdef getprop(duk_context* ctx, str prop):
  "get property from stack-top object, return as python string, leave stack clean"
  cduk.duk_get_prop_string(ctx, -1, prop)
  cdef str res = cduk.duk_safe_to_string(ctx, -1)
  cduk.duk_pop(ctx)
  return res

cdef duk_reraise(duk_context* ctx, int res):
  "for duktape meths that return nonzero to indicate trouble, convert the error object to python and raise it"
  if res:
    err = DuktapeError(*[getprop(ctx, prop) for prop in ('name','message','file','line','stack')])
    cduk.duk_pop(ctx)
    raise err

class DukType:
  "wrapper for integer types that provide extra information"
  def __init__(self, type_int): self.type_int = type_int
  def name(self): raise NotImplementedError
  @classmethod
  def fromname(clas, name): raise NotImplementedError

cdef class DukWrappedObject:
  pass # todo: use this to wrap things that we don't know how to convert to a python object

cdef unsigned int PY_DUK_COMPILE_ARGS

cdef class DukStack:
  "functions that manipulate the JS stack"
  def __init__(self, d_c): self.d_c = d_c
  @property
  def ctx(self): return self.d_c.ctx
  def __len__(self):
    "calls duk_get_top, which is confusingly named. the *index* of the top item is len(stack)-1 (or just -1)"
    return cduk.duk_get_top(self.ctx)
  def get_type(self, index=-1):
    return DukType(cduk.duk_get_type(self.ctx,index))
  def get(self): raise NotImplementedError
  def call(self): raise NotImplementedError
  def tostring(self): raise NotImplementedError

  # object property manipulators
  def get_prop(): raise NotImplementedError
  def set_prop(): raise NotImplementedError
  def call_prop(): raise NotImplementedError
  def construct(self, *args): raise NotImplementedError
  
  # eval
  def eval_file(self, str path): duk_reraise(self.ctx, cduk.duk_peval_file(self.ctx, path))
  def eval_string(self, basestring js): duk_reraise(self.ctx, cduk.duk_peval_string(self.ctx, js))
  
  # compile
  def compile_file(self, str path): duk_reraise(self.ctx, cduk.duk_pcompile_file(self.ctx, PY_DUK_COMPILE_ARGS, path))
  def compile_string(self, basestring js): duk_reraise(self.ctx, cduk.duk_pcompile_string(self.ctx, PY_DUK_COMPILE_ARGS, js))

  # push/pop
  def push_dict(self, d):
    "helper for push"
    cduk.duk_push_object(self.ctx)
    try:
      for k,v in d.items():
        if not isinstance(k,str): raise TypeError('k_not_str', type(k))
        self.push(v)
        cduk.duk_put_prop_string(self.ctx, -2, k)
    except TypeError:
      self.pop() # i.e. cleanup
      raise
  def push_array(self, a):
    "helper for push"
    cduk.duk_push_array(self.ctx)
    try:
      for i,x in enumerate(a):
        self.push(x)
        cduk.duk_put_prop_index(self.ctx, -2, i)
    except TypeError:
      self.pop() # i.e. don't leave stack dirty in error case
      raise
  def push(self, item):
    if isinstance(item, str): duk_push_lstring(self.ctx, item, len(item))
    elif isinstance(item, unicode): raise NotImplementedError('todo: unicode')
    elif isinstance(item, bool): (cduk.duk_push_true if item else cduk.duk_push_false)(self.ctx)
    elif isinstance(item, (int, float)): cduk.duk_push_number(self.ctx, <double>item) # todo: separate ints
    elif isinstance(item, (list, tuple)): self.push_array(item)
    elif isinstance(item, dict): self.push_dict(item)
    elif item is None: cduk.duk_push_null(self.ctx)
    else: raise TypeError('cant_coerce_type', type(item))
  def push_undefined(self): cduk.duk_push_undefined(self.ctx)
  def push_func(self, f, nargs): raise NotImplementedError
  def pop(self, n=1): raise NotImplementedError

cdef class DukContext:
  cdef cduk.duk_context* ctx
  def __cinit__(self): self.ctx = cduk.duk_create_heap_default()
  def __dealloc__(self):
    if self.ctx:
      cduk.duk_destroy_heap(self.ctx)
      self.ctx = NULL

  # misc
  def get_stack(self): return DukStack(self)
  def gc(self): cduk.duk_gc(self.ctx, 0)

  # globals
  def get_global(self, str name): cduk.duk_get_global_string(self.ctx, name)
  def set_global(self, str name): cduk.duk_put_global_string(self.ctx, name)

"""
#define PY_DUK_COPYPROP(prop) duk_get_prop_string(self->context,-1,#prop);\
  PyDict_SetItemString(dict,#prop,PyString_FromString(duk_safe_to_string(self->context,-1)));\
  duk_pop(self->context);

static PyObject* pdc_getprop(pyduk_context* self,PyObject* arg){
  // int arg means index, string arg means key
  // this puts the result on the stack, it *doesn't* return it as a PyObject (because if it's a function you'll want to call it)
  if (PyInt_Check(arg)) duk_get_prop_index(self->context,-1,PyInt_AsLong(arg));
  else if (PyString_Check(arg)) duk_get_prop_string(self->context,-1,PyString_AsString(arg));
  else {
    PyErr_SetString(PyExc_TypeError,"need int or string");
    return 0;
  }
  Py_RETURN_NONE;
}
static PyObject* pdc_setprop(pyduk_context* self,PyObject* arg){
  if (!PyString_Check(arg)) return 0;
  duk_put_prop_string(self->context,-2,PyString_AsString(arg));
  Py_RETURN_NONE;
}

static PyObject* pdc_popn(pyduk_context* self,PyObject* arg){
  unsigned int n=PyInt_AsSsize_t(arg);
  duk_pop_n(self->context,n);
  Py_RETURN_NONE;
}
static PyObject* get_helper(duk_context* ctx,int index){
  if (duk_is_boolean(ctx,index)) return PyBool_FromLong(duk_get_boolean(ctx,index));
  else if (duk_is_nan(ctx,index)) return PyFloat_FromDouble(nan(""));
  else if (duk_is_null_or_undefined(ctx,index)) Py_RETURN_NONE;
  else if (duk_is_number(ctx,index)) return PyFloat_FromDouble(duk_get_number(ctx,index));
  else if (duk_is_string(ctx,index)){
    duk_size_t len;
    const char* buf=duk_get_lstring(ctx,index,&len);
    return PyString_FromStringAndSize(buf,len);
  }
  else if (duk_is_array(ctx,index)){ // must come before object because it's a subset
    duk_size_t len=duk_get_length(ctx,index);
    PyObject* list=PyList_New(len);
    for (unsigned int i=0;i<len;++i){
      duk_get_prop_index(ctx,index,i); // this puts the elt on the stack
      PyList_SetItem(list,i,get_helper(ctx,-1));
      duk_pop(ctx); // and now it's gone
    }
    return list;
  }
  else if (duk_is_object(ctx,index)){
    // will this case trigger for functions and other unexpected things? yuck.
    PyObject* dict=PyDict_New();
    duk_enum(ctx,index,DUK_ENUM_OWN_PROPERTIES_ONLY);
    while (duk_next(ctx,index,true)){ // this pushes k & v onto the stack end
      PyObject* val=get_helper(ctx,-1);
      duk_pop(ctx); // pop the value
      PyObject* key=get_helper(ctx,-1);
      duk_pop(ctx); // pop the key
      PyDict_SetItem(dict,key,val);
    }
    return dict;
  }
  else {
    PyErr_SetString(PyExc_TypeError,"non-coercible type");
    return 0;
  }
}
static PyObject* pdc_get(pyduk_context* self,PyObject* _){
  return get_helper(self->context,-1);
}

const char* PYDUK_FP="__duktape_cfunc_pointer__";
const char* PYDUK_NARGS="__duktape_cfunc_nargs__";

duk_ret_t callback_wrapper(duk_context* ctx){
  duk_push_current_function(ctx);
  // warning: this section dangerously assumes that the props haven't been modified
  duk_get_prop_string(ctx,-1,PYDUK_FP);
  PyObject* callable=(PyObject*)duk_get_pointer(ctx,-1);
  if (!PyCallable_Check(callable)) return DUK_RET_TYPE_ERROR;
  duk_pop(ctx);
  duk_get_prop_string(ctx,-1,PYDUK_NARGS);
  int nargs=duk_get_int(ctx,-1);
  duk_pop_n(ctx,2); // pop nargs and function
  if (nargs==DUK_VARARGS) nargs=duk_get_top(ctx);
  else if (nargs<0) return DUK_RET_RANGE_ERROR;
  if (nargs==DUK_VARARGS||nargs<0) return DUK_RET_UNIMPLEMENTED_ERROR; // notimp, test: I'm not sure what the stack looks like in this case
  PyObject* args_tuple=PyTuple_New(nargs);
  for (int i=0;i<nargs;++i){
    PyObject* item=get_helper(ctx,i);
    if (!item) return DUK_RET_TYPE_ERROR;
    PyTuple_SetItem(args_tuple,i,item);
  }
  PyObject* retval=PyObject_Call(callable,args_tuple,NULL);
  Py_DECREF(args_tuple); // todo: is this right?
  pyduk_context pc;
  pc.context=ctx;
  PyObject* push_res=pdc_push(&pc,retval);
  Py_DECREF(retval); // todo: is this right?
  if (!push_res) return DUK_RET_TYPE_ERROR;
  return 1;
}

static PyObject* pdc_push_func(pyduk_context* self,PyObject* args){
  PyObject* pyfunc; int nargs;
  if (!PyArg_ParseTuple(args,"Oi",&pyfunc,&nargs)) return 0;
  if (!PyCallable_Check(pyfunc)){
    PyErr_SetString(PyExc_TypeError,"args[0] not callable");
    return 0;
  }
  Py_INCREF(pyfunc); // warning: this is a memory leak; but I'm not sure how to create cleanup triggers. read duktape docs, maybe there's a way.
  duk_push_c_function(self->context,callback_wrapper,nargs);
  duk_push_pointer(self->context,(void*)pyfunc);
  duk_put_prop_string(self->context,-2,PYDUK_FP);
  duk_push_int(self->context,nargs);
  duk_put_prop_string(self->context,-2,PYDUK_NARGS);
  Py_RETURN_NONE;
}

static PyObject* pdc_callprop(pyduk_context* self,PyObject* args){
  PyObject* method_name, *jsargs;
  if (!PyArg_ParseTuple(args,"OO",&method_name,&jsargs)) return 0;
  if (!PyString_Check(method_name)||!PyTuple_Check(jsargs)){
    PyErr_SetString(PyExc_TypeError,"expected string, tuple");
    return 0;
  }
  int old_top=duk_get_top(self->context);
  pdc_push(self,method_name);
  unsigned int nargs=PyTuple_Size(jsargs);
  for (unsigned int i=0;i<nargs;++i) pdc_push(self,PyTuple_GetItem(jsargs,i));
  PY_DUK_CATCH(duk_pcall_prop(self->context,old_top-1,nargs))
  Py_RETURN_NONE; // because the object may not be something we can coerce
}

static PyObject* pdc_construct(pyduk_context* self,PyObject* arg){
  if (!PyTuple_Check(arg)) return 0;
  unsigned int nargs=PyTuple_Size(arg);
  for (unsigned int i=0;i<nargs;++i) pdc_push(self,PyTuple_GetItem(arg,i));
  // warning: is there no safe version of new?
  duk_new(self->context,nargs);
  Py_RETURN_NONE;
}
static PyObject* pdc_call(pyduk_context* self,PyObject* arg){
  if (!PyTuple_Check(arg)) return 0;
  if (!duk_is_callable(self->context,-1)){
    PyErr_SetString(PyExc_TypeError,"stack top not callable");
    return 0;
  }
  unsigned int nargs=PyTuple_Size(arg);
  for (unsigned int i=0;i<nargs;++i) pdc_push(self,PyTuple_GetItem(arg,i));
  PY_DUK_CATCH(duk_pcall(self->context,nargs))
  Py_RETURN_NONE;
}
static PyObject* pdc_tostring(pyduk_context* self,PyObject* _){
  return PyString_FromString(duk_safe_to_string(self->context,-1));
}

// todo: py3.4 sig strings https://mail.python.org/pipermail/python-dev/2014-February/132213.html
// todo: C wrapper for passing py funcs, and then classes, to JS -- useful for mocking
static PyMethodDef pyduk_context_meths[]={
  {"eval_file", (PyCFunction)pdc_eval_file, METH_O, "eval_file(filename). leaves a return value on the top of the stack"},
  {"eval_string", (PyCFunction)pdc_eval_string, METH_O, "eval_string(js_source_str). leaves a return value on the top of the stack"},
  {"compile_file", (PyCFunction)pdc_compile_file, METH_O, "compile_file(filename). leaves a return value on the top of the stack"},
  {"compile_string", (PyCFunction)pdc_compile_string, METH_O, "compile_string(js_source_str). leaves a return value on the top of the stack"},
  {"get_type", (PyCFunction)pdc_gettype, METH_O, "get_type(index). type of value at index (pass -1 for top). returns an integer which has duktape meaning"},
  {"push", (PyCFunction)pdc_push, METH_O, "push(pyobject). push python object to JS stack. TypeError if it's something we don't handle"},
  {"push_undefined", (PyCFunction)pdc_push_undefined, METH_NOARGS, "push_undefined(). necessary because None gets coerced to null."},
  {"push_func", (PyCFunction)pdc_push_func, METH_VARARGS, "push_func(callable,nargs). nargs -1 for varargs. WARNING this leaks memory."},
  {"popn", (PyCFunction)pdc_popn, METH_O, "popn(nelts). pop N elts from the stack. doesn't return them, just removes them."},
  {"get", (PyCFunction)pdc_get, METH_NOARGS, "get(). get whatever's at the top of the stack. fail if stack empty or object is not coercible/wrappable."},
  {"get_prop", (PyCFunction)pdc_getprop, METH_O, "get_prop(key). key can be int (index lookup) or string (key lookup)."},
  {"set_prop", (PyCFunction)pdc_setprop, METH_O, "set_prop(key). sets obj[key]=thing if the end of the duktape stack is [obj,thing]."},
  {"call_prop", (PyCFunction)pdc_callprop, METH_VARARGS, "call_prop(function_name,args). args must be a tuple. can be empty."},
  {"get_global", (PyCFunction)pdc_getglobal, METH_O, "get_global(name). look something global up by name"},
  {"set_global", (PyCFunction)pdc_setglobal, METH_O, "set_global(name). set name globally to the thing at the top of the stack."},
  {"construct", (PyCFunction)pdc_construct, METH_O, "construct(args). args is a tuple. the type you're making should be stack-top."},
  {"gc", (PyCFunction)pdc_gc, METH_NOARGS, "gc(). run garbage collector"},
  {"call", (PyCFunction)pdc_call, METH_O, "call(args_tuple). see also call_prop."},
  {"tostring", (PyCFunction)pdc_tostring, METH_NOARGS, "tostring(). return a string representation of the stack top object."},
  {0}
};

}
"""
