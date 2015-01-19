import sys
from distutils.core import setup,Extension

duk_c=Extension(
  'duktape',
  sources=[
    'duktape_c/_duktape.cc',
    'duktape_c/duktape.c',
  ]
)

if sys.version_info[0]!=2:
  raise EnvironmentError('not tested on py3; remove this if you think it should work')

setup(
  name='duktape',
  version='0.0.1',
  description='python wrapper for duktape, an embeddable javascript library',
  ext_modules=[duk_c],
  author='Abe Winter',
  author_email='abe-winter@users.noreply.github.com',
  url='https://github.com/abe-winter/duktape-py',
  keywords=['javascript','duktape'],
)

