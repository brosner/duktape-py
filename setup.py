from distutils.core import setup, Extension


setup(
    name="duktape",
    version="0.0.3",
    description="Python wrapper for duktape, an embeddable Javascript library",
    ext_modules=[
        Extension(
            "duktape",
            sources=[
                "duktape.c",
                "duktape_c/duktape.c",
            ]
        )
    ],
    author="Brian Rosner",
    author_email="brosner@gmail.com",
    url="https://github.com/brosner/duktape-py",
    keywords=["javascript", "duktape"],
)
