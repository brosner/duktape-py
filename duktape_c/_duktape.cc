// ultra-basic wrapper module for duktape

#include "Python.h"
#include "duktape.h"

static PyObject* DuktapeError=0;

#define PY_DUK_COPYPROP(prop) duk_get_prop_string(self->context,-1,#prop);\
  PyDict_SetItemString(dict,#prop,PyString_FromString(duk_safe_to_string(self->context,-1)));\
  duk_pop(self->context);

#define PY_DUK_CATCH(call)  if (call){\
  PyObject* dict=PyDict_New();\
  PY_DUK_COPYPROP(name);\
  PY_DUK_COPYPROP(message);\
  PY_DUK_COPYPROP(file);\
  PY_DUK_COPYPROP(line);\
  PY_DUK_COPYPROP(stack);\
  duk_pop(self->context);\
  PyErr_SetObject(DuktapeError,dict);\
  return 0;\
}

struct pyduk_context {
  PyObject_HEAD
  duk_context* context;
};

static void pyduk_ctx_dealloc(pyduk_context* self){
  duk_destroy_heap(self->context);
  self->context=0;
  self->ob_type->tp_free((PyObject*)self);
}
static PyObject* pyduk_ctx_New(PyTypeObject* type,PyObject* args, PyObject* kwds){
  pyduk_context* self=(pyduk_context*)type->tp_alloc(type,0);
  self->context=0;
  if (self) self->context=duk_create_heap_default();
  return (PyObject*)self;
}

static PyObject* pdc_eval_file(pyduk_context* self,PyObject* arg){
  const char* path=PyString_AsString(arg);
  if (!path) return 0;
  PY_DUK_CATCH(duk_peval_file(self->context,path))
  Py_RETURN_NONE;
}
static PyObject* pdc_eval_string(pyduk_context* self,PyObject* arg){
  // nextup: setjmp here
  const char* src=PyString_AsString(arg);
  if (!src) return 0; // did py set the error?
  PY_DUK_CATCH(duk_peval_string(self->context,src))
  Py_RETURN_NONE;
}

#define PY_DUK_COMPILE_ARGS 0
static PyObject* pdc_compile_file(pyduk_context* self,PyObject* arg){
  const char* path=PyString_AsString(arg);
  if (!path) return 0;
  PY_DUK_CATCH(duk_pcompile_file(self->context,PY_DUK_COMPILE_ARGS,path))
  Py_RETURN_NONE;
}
static PyObject* pdc_compile_string(pyduk_context* self,PyObject* arg){
  // nextup: setjmp here
  const char* src=PyString_AsString(arg);
  if (!src) return 0; // did py set the error?
  PY_DUK_CATCH(duk_pcompile_string(self->context,PY_DUK_COMPILE_ARGS,src))
  Py_RETURN_NONE;
}

static PyObject* pdc_stacklen(pyduk_context* self,PyObject* arg){
  return PyInt_FromSsize_t(duk_get_top(self->context));
}
static PyObject* pdc_gettype(pyduk_context* self,PyObject* arg){
  unsigned int index=PyInt_AsSsize_t(arg); // todo: typecheck
  return PyInt_FromSsize_t(duk_get_type(self->context,index));
}
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
static PyObject* pdc_push(pyduk_context* self,PyObject* arg){
  if (PyString_Check(arg)){
    char* buf; Py_ssize_t len;
    PyString_AsStringAndSize(arg,&buf,&len);
    duk_push_lstring(self->context,buf,len);
  }
  else if (PyBool_Check(arg)){ // bool check comes before int because PyInt_Check(bool_object) works
    if (arg==Py_True) duk_push_true(self->context);
    else duk_push_false(self->context);
  }
  else if (PyInt_Check(arg)||PyFloat_Check(arg)){
    duk_push_number(self->context,(double)(PyInt_Check(arg)?PyInt_AsLong(arg):PyFloat_AsDouble(arg)));
  }
  else if (PyList_Check(arg)||PyTuple_Check(arg)){
    duk_push_array(self->context);
    unsigned int object_index=duk_get_top_index(self->context);
    Py_ssize_t len=PyList_Check(arg)?PyList_Size(arg):PyTuple_Size(arg);
    for (unsigned int i=0;i<len;++i){
      pdc_push(self,(PyList_Check(arg)?PyList_GetItem:PyTuple_GetItem)(arg,i));
      duk_put_prop_index(self->context,object_index,i);
    }
  }
  else if (PyDict_Check(arg)){
    duk_push_object(self->context);
    unsigned int object_index=duk_get_top_index(self->context);
    Py_ssize_t pos=0; PyObject* key,*val;
    while (PyDict_Next(arg,&pos,&key,&val)){
      if (!PyString_Check(key)) return 0; // todo: consider cast to JSON with a flag
      // todo below: AsStringAndSize so these don't have to be null-term-able
      pdc_push(self,val);
      duk_put_prop_string(self->context,object_index,PyString_AsString(key));
    }
  }
  else if (arg==Py_None) duk_push_null(self->context);
  // todo: case for callable with varargs
  else {
    PyErr_SetString(PyExc_TypeError,"non-coercible type");
    return 0;
  }
  Py_RETURN_NONE;
}
static PyObject* pdc_push_undefined(pyduk_context* self,PyObject* _){
  duk_push_undefined(self->context);
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
static PyObject* pdc_getglobal(pyduk_context* self,PyObject* arg){
  char* name=PyString_AsString(arg);
  if (!name) return 0;
  duk_get_global_string(self->context,name);
  Py_RETURN_NONE;
}
static PyObject* pdc_setglobal(pyduk_context* self,PyObject* arg){
  char* name=PyString_AsString(arg);
  if (!name) return 0;
  duk_put_global_string(self->context,name);
  Py_RETURN_NONE;
}
static PyObject* pdc_construct(pyduk_context* self,PyObject* arg){
  if (!PyTuple_Check(arg)) return 0;
  unsigned int nargs=PyTuple_Size(arg);
  for (unsigned int i=0;i<nargs;++i) pdc_push(self,PyTuple_GetItem(arg,i));
  // warning: is there no safe version of new?
  duk_new(self->context,nargs);
  Py_RETURN_NONE;
}
static PyObject* pdc_gc(pyduk_context* self,PyObject* _){
  duk_gc(self->context,0);
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

// todo: py3.4 sig strings https://mail.python.org/pipermail/python-dev/2014-February/132213.html
// todo: C wrapper for passing py funcs, and then classes, to JS -- useful for mocking
static PyMethodDef pyduk_context_meths[]={
  {"eval_file", (PyCFunction)pdc_eval_file, METH_O, "eval_file(filename). leaves a return value on the top of the stack"},
  {"eval_string", (PyCFunction)pdc_eval_string, METH_O, "eval_string(js_source_str). leaves a return value on the top of the stack"},
  {"compile_file", (PyCFunction)pdc_compile_file, METH_O, "compile_file(filename). leaves a return value on the top of the stack"},
  {"compile_string", (PyCFunction)pdc_compile_string, METH_O, "compile_string(js_source_str). leaves a return value on the top of the stack"},
  {"stacklen", (PyCFunction)pdc_stacklen, METH_NOARGS, "stacklen(). calls duk_get_top, which is confusingly named. use result - 1 for anything wanting a stack index."},
  {"get_type", (PyCFunction)pdc_gettype, METH_O, "get_type(index). type of value at index (pass -1 for top). returns an integer which has duktape meaning"},
  {"push", (PyCFunction)pdc_push, METH_O, "push(pyobject). push python object to JS stack. TypeError if it's something we don't handle"},
  {"push_undefined", (PyCFunction)pdc_push_undefined, METH_NOARGS, "push_undefined(). necessary because None gets coerced to null."},
  {"push_func", (PyCFunction)pdc_push_func, METH_VARARGS, "push_func(cfuncptr,nargs). nargs -1 for varargs. WARNING this leaks memory."},
  {"popn", (PyCFunction)pdc_popn, METH_O, "popn(nelts). pop N elts from the stack. doesn't return them, just removes them."},
  {"get", (PyCFunction)pdc_get, METH_NOARGS, "get(). get whatever's at the top of the stack. fail if stack empty or object is not coercible/wrappable."},
  {"get_prop", (PyCFunction)pdc_getprop, METH_O, "get_prop(key). key can be int (index lookup) or string (key lookup)."},
  {"call_prop", (PyCFunction)pdc_callprop, METH_VARARGS, "call_prop(function_name,args). args must be a tuple. can be empty."},
  {"get_global", (PyCFunction)pdc_getglobal, METH_O, "get_global(name). look something global up by name"},
  {"set_global", (PyCFunction)pdc_setglobal, METH_O, "set_global(name). set name globally to the thing at the top of the stack."},
  {"construct", (PyCFunction)pdc_construct, METH_O, "construct(args). args is a tuple. the type you're making should be stack-top."},
  {"gc", (PyCFunction)pdc_gc, METH_NOARGS, "gc(). run garbage collector"},
  {"call", (PyCFunction)pdc_call, METH_O, "call(args_tuple). see also call_prop."},
  {0}
};

static PyTypeObject duk_context_type = {
  PyObject_HEAD_INIT(0)
  0,                         /*ob_size*/
  "duktape.duk_context",             /*tp_name*/
  sizeof(pyduk_context), /*tp_basicsize*/
  0,                         /*tp_itemsize*/
  (destructor)pyduk_ctx_dealloc, // tp_dealloc
  0,                         /*tp_print*/
  0,                         /*tp_getattr*/
  0,                         /*tp_setattr*/
  0,                         /*tp_compare*/
  0,                         /*tp_repr*/
  0,                         /*tp_as_number*/
  0,                         /*tp_as_sequence*/
  0,                         /*tp_as_mapping*/
  0,                         /*tp_hash */
  0,                         /*tp_call*/
  0,                         /*tp_str*/
  0,                         /*tp_getattro*/
  0,                         /*tp_setattro*/
  0,                         /*tp_as_buffer*/
  Py_TPFLAGS_DEFAULT,        /*tp_flags*/
  "python wrapper for C duk_context", // tp_doc
};

static PyMethodDef module_meths[]={{0}};

extern "C" {

void initduktape(){
  duk_context_type.tp_methods=pyduk_context_meths;
  duk_context_type.tp_new=pyduk_ctx_New;
  if (PyType_Ready(&duk_context_type) < 0) return;
  PyObject* module = Py_InitModule3("duktape", module_meths, "wrapper for duktape JS engine");
  if (!module) return;
  // duk_context
  Py_INCREF(&duk_context_type);
  PyModule_AddObject(module, "duk_context", (PyObject*)&duk_context_type);
  // JSError
  DuktapeError=PyErr_NewException("duktape.DuktapeError",NULL,NULL);
  Py_INCREF(DuktapeError);
  PyModule_AddObject(module,"DuktapeError",DuktapeError);
}

}
