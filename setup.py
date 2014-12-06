from distutils.core import setup,Extension

duk_c=Extension(
  'duktape',
  sources=[
    'duktape_c/_duktape.cc',
    'duktape_c/duktape.c',
  ]
)

setup(
  name='duktape',
  version='0.0.0',
  description='python wrapper for duktape C library',
  ext_modules=[duk_c]
)

