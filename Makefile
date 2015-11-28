build:
	cython duktape.pyx
	python setup.py build_ext --inplace

clean:
	rm -rf build/ duktape.c duktape*.so

.PHONY: build clean
