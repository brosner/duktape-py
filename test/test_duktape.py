import gc
import tempfile

import duktape
import pytest

# todo: unicode tests everywhere and strings with nulls (i.e. I'm relying on null termination)


def test_create():
    duktape.Context()


def test_eval_file():
    ctx = duktape.Context()
    with tempfile.NamedTemporaryFile() as tf:
        tf.write(b"var a = {a: 1, b: 2};")
        tf.flush()
        ctx.load(tf.name)
    assert len(ctx) == 1


def test_stacklen_evalstring():
    "test stacklen and evalstring"
    ctx = duktape.Context()
    assert len(ctx) == 0
    ctx.loads("var a = '123';")
    assert len(ctx) == 1


def test_error_handling():
    ctx = duktape.Context()
    with pytest.raises(duktape.Error):
        ctx.loads("bad syntax bad bad bad")


def test_gc():
    ctx = duktape.Context()
    ctx._push("whatever")
    ctx.gc()


def test_push_gettype():
    "test _push and _type"
    ctx = duktape.Context()

    def push(x):
        ctx._push(x)
        return ctx._type()

    codes = map(push, [
        "123",
        123,
        123.,
        True,
        False,
        None,
        (1, 2, 3),
        [1, 2, 3],
        [[1]],
        {
            "a": 1,
            "b": "2",
        }
    ])
    expected = [str, float, float, bool, bool, type(None), object, object, object, object]
    assert [code.as_pytype() for code in codes] == expected


def test_push_get():
    ctx = duktape.Context()
    for v in ["123", 123., True, False, [1, 2, 3], [[1]], {"a": 1, "b": 2}]:
        ctx._push(v)
        assert v == ctx._get()
