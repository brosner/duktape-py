import duktape,pytest,tempfile

# todo: unicode tests everywhere and strings with nulls (i.e. I'm relying on null termination)

def test_create(): duktape.DukContext()
def test_eval_file():
  c=duktape.DukContext()
  with tempfile.NamedTemporaryFile() as tf:
    tf.write('var a={a:1,b:2};')
    tf.flush()
    c.eval_file(tf.name)
  assert len(c)==1
def test_stacklen_evalstring():
  "test stacklen and evalstring"
  c=duktape.DukContext()
  assert len(c)==0
  c.eval_string('var a="123";')
  assert len(c)==1
def test_error_handling():
  c=duktape.DukContext()
  # if error handling *isn't* working, this sends a SIGABRT
  with pytest.raises(duktape.DuktapeError): c.eval_string('bad syntax bad bad bad')
def test_gc():
  c=duktape.DukContext()
  c.push('whatever')
  c.gc() # I don't know how to test memory usage without a lot of work. so this just exercises it.

def test_push_gettype():
  "test push and gettype"
  c=duktape.DukContext()
  def push(x):
    c.push(x)
    return c.get_type()
  codes=map(push,['123',123,123.,True,False,None,(1,2,3),[1,2,3],[[1]],{'a':1,'b':'2'}]);
  print 'codes',codes
  assert [code.type() for code in codes]==[str,float,float,bool,bool,type(None),object,object,object,object]
  c.push_undefined()
  assert c.get_type().type()=='undefined'
def test_push_get():
  c=duktape.DukContext()
  for v in ['123',123.,True,False,[1,2,3],[[1]],{'a':1,'b':2}]:
    c.push(v)
    assert v==c.get()
    print v

# SECTION: properties and function calls
CLASSINSTANCE="""function C(a,b){this.a=a; this.b=b;}
C.prototype.tot=function(){return this.a+this.b;}
new C(1,1);"""

def test_get_twice():
  "when I wrote this get() wasn't cleaning up after itself"
  c=duktape.DukContext()
  c.eval_string("function C(a,b){this.a=a; this.b=b;}")
  c.get_global('C')
  c.construct(1,[2,3])
  assert len(c)==2
  assert c.get()=={'a':1.,'b':[2.,3.]}
  assert len(c)==2
  assert c.get()=={'a':1.,'b':[2.,3.]}
  assert len(c)==2

def test_getprop():
  c=duktape.DukContext()
  c.eval_string(CLASSINSTANCE)
  c.get_prop('a')
  assert c.get()==1.
  c.pop()
  assert c.get()=={'a':1.,'b':1.}
def test_setprop():
  c=duktape.DukContext()
  c.push({})
  c.push(1)
  c.set_prop('k')
  assert c.get()=={'k':1.}
def test_call_prop():
  c=duktape.DukContext()
  c.eval_string(CLASSINSTANCE)
  c.call_prop('tot',())
  assert c.get()==2

@pytest.mark.xfail
def test_call_prop_errors():
  # 1. arg error
  # 2. error during call
  raise NotImplementedError

def test_global():
  c=duktape.DukContext()
  c.eval_string(CLASSINSTANCE)
  assert len(c)==1
  c.get_global('C')
  assert len(c)==2 and c.get_type().type() is object
def test_construct():
  c=duktape.DukContext()
  c.eval_string(CLASSINSTANCE)
  c.get_global('C')
  c.construct(1,2)
  assert c.get()=={'a':1,'b':2}
def test_call():
  c=duktape.DukContext()
  c.eval_string('(function(a,b){return a+b;})')
  c.call(1,2)
  print c.get()
  assert c.get()==3.

def test_push_func():
  # -1 is DUK_VARARGS
  # typedef duk_ret_t (*duk_safe_call_function) (duk_context *ctx);
  # and duk_ret_t is just an int, here: http://duktape.org/guide.html#ctypes.2
  # this has info about return values: http://duktape.org/api.html#duk_push_c_function
  def zero(): return 'ok'
  def onearg(arg): return arg+1
  def varargs(*args): return args[1:]
  c=duktape.DukContext()
  c.push_func(zero,0)
  c.call()
  assert 'ok'==c.get()
  c.push_func(onearg,1)
  c.call(1)
  assert 2==c.get()
  c.push_func(varargs,-1)
  c.call(1,2,3)
  assert [2.,3.]==c.get()

def test_mockattr():
  c=duktape.DukContext()
  c.push({})
  def fake_member(a,b): return a+b
  c.push_func(fake_member,2)
  c.set_prop('add')
  c.call_prop('add',(1,2))
  assert 3.==c.get()
  c.pop()
