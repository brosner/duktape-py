import sys
from distutils.core import setup,Extension
from Cython.Build import cythonize

duk_c=Extension(
  'duktape',
  sources=[
    'duktape.pyx',
    'duktape_c/duktape.c',
  ]
)

setup(
  name='duktape',
  version='0.0.3',
  description='python wrapper for duktape, an embeddable javascript library',
  ext_modules=cythonize([duk_c]),
  author='Abe Winter',
  author_email='abe-winter@users.noreply.github.com',
  url='https://github.com/abe-winter/duktape-py',
  keywords=['javascript','duktape'],
)
