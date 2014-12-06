// ultra-basic wrapper module for duktape

#include "Python.h"
#include "duktape.h"

static PyObject* DuktapeError;

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
  if (duk_peval_file(self->context,path)){
    PyErr_SetString(DuktapeError,duk_safe_to_string(self->context,-1));
    duk_pop(self->context);
    return 0;
  }
  Py_RETURN_NONE;
}
static PyObject* pdc_eval_string(pyduk_context* self,PyObject* arg){
  // nextup: setjmp here
  const char* src=PyString_AsString(arg);
  if (!src) return 0; // did py set the error?
  if (duk_peval_string(self->context,src)){
    PyErr_SetString(DuktapeError,duk_safe_to_string(self->context,-1));
    duk_pop(self->context); // pop the error
    return 0;
  }
  Py_RETURN_NONE;
}
static PyObject* pdc_stacklen(pyduk_context* self,PyObject* arg){
  return PyInt_FromSsize_t(duk_get_top(self->context));
}
static PyObject* pdc_gettype(pyduk_context* self,PyObject* arg){
  unsigned int index=PyInt_AsSsize_t(arg); // todo: typecheck
  return PyInt_FromSsize_t(duk_get_type(self->context,index));
}
static PyObject* pdc_push(pyduk_context* self,PyObject* arg); // fwd dec
static PyObject* pdc_getprop(pyduk_context* self,PyObject* arg){
  // int arg means index, string arg means key
  // this puts the result on the stack, it *doesn't* return it as a PyObject (because if it's a function you'll want to call it)
  if (PyInt_Check(arg)) duk_get_prop_index(self->context,-1,PyInt_AsLong(arg));
  else if (PyString_Check(arg)) duk_get_prop_string(self->context,-1,PyString_AsString(arg));
  else return 0; // todo typeerror
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
      if (!PyString_Check(key)) return 0; // todo: real exception. todo: cast to JSON?
      // todo below: AsStringAndSize so these don't have to be null-term-able
      pdc_push(self,val);
      duk_put_prop_string(self->context,object_index,PyString_AsString(key));
    }
  }
  else if (arg==Py_None){
    // hmm: how do I push an undefined, then?
    duk_push_null(self->context);
  }
  else return 0; // todo raise a real exception
  Py_RETURN_NONE;
}
static PyObject* pdc_popn(pyduk_context* self,PyObject* arg){
  unsigned int n=PyInt_AsSsize_t(arg);
  duk_pop_n(self->context,n);
  Py_RETURN_NONE;
}
static PyObject* pdc_get(pyduk_context* self,PyObject* _){
  if (duk_is_boolean(self->context,-1)) return PyBool_FromLong(duk_get_boolean(self->context,-1));
  else if (duk_is_nan(self->context,-1)) return PyFloat_FromDouble(nan(""));
  else if (duk_is_null_or_undefined(self->context,-1)) Py_RETURN_NONE;
  else if (duk_is_number(self->context,-1)) return PyFloat_FromDouble(duk_get_number(self->context,-1));
  else if (duk_is_string(self->context,-1)){
    duk_size_t len;
    const char* buf=duk_get_lstring(self->context,-1,&len);
    return PyString_FromStringAndSize(buf,len);
  }
  else if (duk_is_array(self->context,-1)){ // must come before object because it's a subset
    duk_size_t len=duk_get_length(self->context,-1);
    PyObject* list=PyList_New(len);
    for (unsigned int i=0;i<len;++i){
      duk_get_prop_index(self->context,-1,i); // this puts the elt on the stack
      PyList_SetItem(list,i,pdc_get(self,0)); // pdc_get uses it from the end of the stack
      duk_pop(self->context); // and now it's gone
    }
    return list;
  }
  else if (duk_is_object(self->context,-1)){
    // will this case trigger for functions and other unexpected things? yuck.
    PyObject* dict=PyDict_New();
    duk_enum(self->context,-1,DUK_ENUM_OWN_PROPERTIES_ONLY);
    while (duk_next(self->context,-1,true)){ // this pushes k & v onto the stack end
      PyObject* val=pdc_get(self,0);
      duk_pop(self->context); // pop the value
      PyObject* key=pdc_get(self,0);
      duk_pop(self->context); // pop the key
      PyDict_SetItem(dict,key,val);
    }
    return dict;
  }
  else {
    PyErr_SetString(PyExc_TypeError,"non-coercible type");
    return 0;
  }
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
  if (duk_pcall_prop(self->context,old_top-1,nargs)){
    PyErr_SetString(DuktapeError,duk_safe_to_string(self->context,-1));
    duk_pop(self->context);
    return 0;
  }
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
  if (duk_pcall(self->context,nargs)){
    PyErr_SetString(DuktapeError,duk_safe_to_string(self->context,-1));
    duk_pop(self->context);
    return 0;
  }
  Py_RETURN_NONE;
}

static PyMethodDef pyduk_context_meths[]={
  {"eval_file", (PyCFunction)pdc_eval_file, METH_O, "eval_file(filename). leaves a return value on the top of the stack"},
  {"eval_string", (PyCFunction)pdc_eval_string, METH_O, "eval_string(js_source_str). leaves a return value on the top of the stack"},
  {"stacklen", (PyCFunction)pdc_stacklen, METH_NOARGS, "stacklen(). calls duk_get_top, which is confusingly named. use result - 1 for anything wanting a stack index."},
  {"get_type", (PyCFunction)pdc_gettype, METH_O, "get_type(index). type of value at index (pass -1 for top). returns an integer which has duktape meaning"},
  {"push", (PyCFunction)pdc_push, METH_O, "push(pyobject). push python object to JS stack. TypeError if it's something we don't handle"},
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
