var page = require('webpage').create();  
var system = require('system');
var resources = [];

/*
page.onError = function(msg, trace) {

  var msgStack = ['ERROR: ' + msg];

  if (trace && trace.length) {
    msgStack.push('TRACE:');
    trace.forEach(function(t) {
      msgStack.push(' -> ' + t.file + ': ' + t.line + (t.function ? ' (in function "' + t.function +'")' : ''));
    });
  }

  console.error(msgStack.join('\n'));

};
*/

page.onResourceReceived = function(response) {
  if (response.stage === 'end') {
    resources.push(response.status);
  }
};

page.open(system.args[1], function(status) {  
  // console.log('Status: ' + status);
  
  if ( status !== 'success' ) {
    console.log('Unable to load the address!');
    phantom.exit();
  } else if ( resources.indexOf(404) != -1 ) {
    console.log('Resources include 404.');
    phantom.exit();
  } else if ( resources.indexOf(500) != -1 ) {
    console.log('Resources include 500.');
    phantom.exit();
  } else {
    window.setTimeout(function () {
      w = 64;
      h = 64;
      
      if ( !!system.args[3] && !!system.args[4] ) {
        w = system.args[3];
        h = system.args[4];
      }
      
      // console.log('Viewport Size: ' + w + 'x' + h);
      
      page.viewportSize = {width: w, height: h};
      page.render(system.args[2]);
      phantom.exit();
    }, 1000); // Change timeout as required to allow sufficient time 
  }
});
