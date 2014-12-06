duktape-py
==========
python wrapper for duktape, an embeddable javascript engine

# demo
```python
>>> import duktape
>>> c=duktape.duk_context()
>>> c.eval_string("""function C(a,b){this.a=a; this.b=b};
... C.prototype.tot=function(){return this.a+this.b};
... new C(1,2);""")
>>> c.get()
{'a': 1.0, 'b': 2.0}
>>> c.call_prop('tot',())
>>> c.get()
3.0
```

```python
>>> def pushget(x): c.push(x); return c.get()
... 
>>> map(pushget,[1,2.,'three',[4,5],{'6':7},[[8]]])
[1.0, 2.0, 'three', [4.0, 5.0], {'6': 7.0}, [[8.0]]]
```

```python
>>> c.get_global("C")
>>> c.construct((1,2))
>>> c.get()
{'a': 1.0, 'b': 2.0}
```

but tread lightly:

```python
>>> c.push('not_a_function')
>>> c.construct((1,2))
FATAL 56: uncaught error
PANIC 56: uncaught error (calling abort)
Abort trap: 6
```

# installation
```bash
git clone <whatever>
cd duktape-py
python -m setup install
# that's it
# we're not in pypi yet
```

# why?
* `pyv8` is fine if you want boost on your system
* being able to run JS from python lets you run integration tests without standing up client-server infrastructure -- makes tests faster and more reliable

# warnings
* use this for testing only
* note the version (0.0.0)
* don't run in production unless you like `SIGABRT` 
* this isn't full-featured; most of duktape *isn't* exposed 
* this is *almost* as low-level as duktape so you'll have to interact with the stack
