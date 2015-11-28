from distutils.core import setup, Extension


setup(
    name="duktape",
    version="0.0.3",
    description="python wrapper for duktape, an embeddable javascript library",
    ext_modules=[
        Extension(
            "duktape",
            sources=[
                "duktape.c",
                "duktape_c/duktape.c",
            ]
        )
    ],
    author="Abe Winter",
    author_email="abe-winter@users.noreply.github.com",
    url="https://github.com/abe-winter/duktape-py",
    keywords=["javascript", "duktape"],
)
