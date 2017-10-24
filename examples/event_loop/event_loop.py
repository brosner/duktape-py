"""
This file represents how to implement an event loop for duktape using asyncio.
"""
import asyncio
from functools import partial

import duktape


class Timer:

    def __init__(self, event_loop, callback, delay, oneshot=True):
        self.event_loop = event_loop
        self.callback = callback
        self.delay = delay
        self.oneshot = oneshot
        self.cancelled = False
        self.done = False
        self.schedule()

    def __call__(self, *args):
        if not self.cancelled:
            try:
                self.callback(*args)
            except Exception:
                self.done = True
                raise
            else:
                if not self.oneshot:
                    self.schedule()
                else:
                    self.done = True
            finally:
                self.event_loop.tick()

    def schedule(self):
        if not self.cancelled:
            self._handle = self.event_loop.loop.call_later(self.delay, self)

    def cancel(self):
        self._handle.cancel()
        self.cancelled = True
        self.done = True

    def __repr__(self):
        return f"<Timer {id(self)} callback={self.callback} delay={self.delay} oneshot={self.oneshot} cancelled={self.cancelled}>"


class EventLoop:

    loop = asyncio.get_event_loop()

    @classmethod
    def setup(cls, ctx):
        event_loop = cls()
        ctx.load("event_loop.js")
        ctx["EventLoop"] = {
            "createTimer": duktape.PyFunc(event_loop.create_timer, 3),
            "cancelTimer": duktape.PyFunc(event_loop.cancel_timer, 1),
        }
        return event_loop

    def __init__(self):
        self.timers = []

    def create_timer(self, callback, delay, oneshot):
        self.timers.append(Timer(self, callback, delay / 1000, oneshot))
        return len(self.timers) - 1

    def cancel_timer(self, idx):
        timer = self.timers.pop(int(idx))
        timer.cancel()

    def tick(self):
        for timer in self.timers:
            if not timer.done:
                break
        else:
            self.completed.set_result(None)

    def run(self):
        self.completed = self.loop.create_future()
        self.tick()
        self.loop.run_until_complete(self.completed)


def user_code(ctx):
    ctx.load("demo.js")


def console_log(message):
    print(message)


def setup_duk_ctx():
    ctx = duktape.Context()
    ctx["console"] = {"log": duktape.PyFunc(console_log, 1)}
    event_loop = EventLoop.setup(ctx)
    return ctx, event_loop


duk_ctx, event_loop = setup_duk_ctx()
event_loop.create_timer(partial(user_code, duk_ctx), 0, True)
event_loop.run()
