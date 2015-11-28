build:
	cython duktape.pyx
	python setup.py build_ext --inplace

test: build
	py.test -xv

clean:
	rm -rf build/ duktape*.so *.egg-info .cache

.PHONY: build clean
