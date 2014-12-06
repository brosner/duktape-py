import duktape,pytest

# todo: unicode tests everywhere and strings with nulls (i.e. I'm relying on null termination)

TYPES={
  2:type(None),
  3:bool,
  4:float,
  5:str,
  6:object,
}

def test_create(): duktape.duk_context()
def test_eval_file():
  c=duktape.duk_context()
  fname='test_eval_file.js'
  open(fname,'w').write('var a={a:1,b:2};')
  c.eval_file(fname)
  assert c.stacklen()==1
def test_stacklen_evalstring():
  "test stacklen and evalstring"
  c=duktape.duk_context()
  assert c.stacklen()==0
  c.eval_string('var a="123";')
  assert c.stacklen()==1
def test_error_handling():
  c=duktape.duk_context()
  # if error handling *isn't* working, this sends a SIGABRT
  with pytest.raises(duktape.DuktapeError): c.eval_string('bad syntax bad bad bad')
def test_gc():
  c=duktape.duk_context()
  c.push('whatever')
  c.gc() # I don't know how to test memory usage without a lot of work. so this just exercises it.

def test_push_gettype():
  "test push and gettype"
  c=duktape.duk_context()
  def push(x):
    c.push(x)
    return c.get_type(c.stacklen()-1)
  codes=map(push,['123',123,123.,True,False,None,(1,2,3),[1,2,3],[[1]],{'a':1,'b':'2'}]);
  assert map(TYPES.__getitem__,codes)==[str,float,float,bool,bool,type(None),object,object,object,object]
def test_push_get():
  c=duktape.duk_context()
  for v in ['123',123.,True,False,[1,2,3],[[1]],{'a':1,'b':2}]:
    c.push(v)
    assert v==c.get()
    print v

# SECTION: properties and function calls
CLASSINSTANCE="""function C(a,b){this.a=a; this.b=b;}
C.prototype.tot=function(){return this.a+this.b;}
new C(1,1);"""
def test_getprop():
  c=duktape.duk_context()
  c.eval_string(CLASSINSTANCE)
  c.get_prop('a')
  assert c.get()==1.
  c.popn(1)
  assert c.get()=={'a':1.,'b':1.}
def test_call_prop():
  c=duktape.duk_context()
  c.eval_string(CLASSINSTANCE)
  c.call_prop('tot',())
  assert c.get()==2
def test_global():
  c=duktape.duk_context()
  c.eval_string(CLASSINSTANCE)
  assert c.stacklen()==1
  c.get_global('C')
  assert c.stacklen()==2 and c.get_type(-1)==6
def test_construct():
  c=duktape.duk_context()
  c.eval_string(CLASSINSTANCE)
  c.get_global('C')
  c.construct((1,2))
  assert c.get()=={'a':1,'b':2}
def test_call():
  c=duktape.duk_context()
  c.eval_string('(function(a,b){return a+b;})')
  c.call((1,2))
  print c.get()
  assert c.get()==3.
