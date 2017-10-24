
var timer = setInterval(function() {
  console.log('hello world');
}, 1000);

setTimeout(function() {
  clearInterval(timer);
}, 1000 * 10);
