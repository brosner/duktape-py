
function setTimeout(func, delay) {
  var cbFunc, bindArgs;
  if (typeof delay !== 'number') {
    throw new TypeError('delay is not a number');
  }
  if (typeof func === 'string') {
    cbFunc = eval.bind(this, func);
  } else if (typeof func !== 'function') {
    throw new TypeError('callback is not a function/string');
  } else if (arguments.length > 2) {
    bindArgs = Array.prototype.slice.call(arguments, 2);  // [ arg1, arg2, ... ]
    bindArgs.unshift(this);  // [ global(this), arg1, arg2, ... ]
    cbFunc = func.bind.apply(func, bindArgs);
  } else {
    cbFunc = func;
  }
  return EventLoop.createTimer(cbFunc, delay, true);
}

function setInterval(func, delay) {
  var cbFunc, bindArgs;
  if (typeof delay !== 'number') {
    throw new TypeError('delay is not a number');
  }
  if (typeof func === 'string') {
    cbFunc = eval.bind(this, func);
  } else if (typeof func !== 'function') {
    throw new TypeError('callback is not a function/string');
  } else if (arguments.length > 2) {
    bindArgs = Array.prototype.slice.call(arguments, 2);  // [ arg1, arg2, ... ]
    bindArgs.unshift(this);  // [ global(this), arg1, arg2, ... ]
    cbFunc = func.bind.apply(func, bindArgs);
  } else {
    cbFunc = func;
  }
  return EventLoop.createTimer(cbFunc, delay, false);
}

function clearInterval(timerId) {
  return EventLoop.cancelTimer(timerId);
}
