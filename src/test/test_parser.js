// Generated by CoffeeScript 1.6.2
(function() {
  var parse, parser, xexports;

  parser = require('../parser');

  parser.yy = require('../../lib/coffee-script/nodes');

  parse = function(code) {
    return parser.parse(code);
  };

  xexports = {};

  exports.Test = {
    "test atomic": function(test) {
      test.equal(parse('3'), 3);
      return test.done();
    }
  };

}).call(this);

/*
//@ sourceMappingURL=test_parser.map
*/