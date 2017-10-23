from setuptools import setup, Extension

setup(
    name="duktape",
    version="0.1.0",
    description="Python wrapper for duktape, an embeddable Javascript library",
    ext_modules=[
        Extension(
            "duktape",
            sources=[
                "duktape.c",
                "duktape_c/duktape.c",
            ],
            libraries=["m"],
        )
    ],
    author="Brian Rosner",
    author_email="brosner@gmail.com",
    url="https://github.com/brosner/duktape-py",
    keywords=["javascript", "duktape"],
)
