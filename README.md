duktape-py
==========

This project was originally Abe Winter's, but he has transferred ownership over
to me (Brian Rosner). I plan on fixing issues and implementing new features. I
have already started supporting Python 3 and updated duktape to 1.3.1. More to
come, so stay tuned!

Python wrapper for duktape, an embeddable Javascript engine

# demo
```python
>>> import duktape
>>> c=duktape.DukContext()
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
>>> c.construct(1,2)
>>> c.get()
{'a': 1.0, 'b': 2.0}
```

you can make python functions callable from javascript (though it leaks memory and you can't bind a 'this'):

```python
>>> def add(a,b): return a+b
...
>>> c.push_func(add,2)
>>> c.call(1,2)
>>> c.get()
3.0
```

Tread lightly: not all errors are caught. In particular, errors in a constructor function aren't handled.

# installation
```bash
pip install duktape
```

# why?
* `pyv8` is fine if you want boost on your system
* being able to run JS from python lets you run integration tests without standing up client-server infrastructure -- makes tests faster and more reliable

# warnings
* use this for testing only
* note the version (0.0.2). this is not mature.
* don't run in production unless you like `SIGABRT`
* this isn't full-featured; most of duktape *isn't* exposed
* this is *almost* as low-level as duktape so you'll have to interact with the stack
