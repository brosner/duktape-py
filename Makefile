duktape.c: duktape.pyx
	cython duktape.pyx

build: duktape.c
	python setup.py build_ext --inplace

test: build
	py.test -xv

clean:
	rm -rf build/ duktape*.so *.egg-info .cache

.PHONY: build clean
