parser = require('../parser')

parser.yy = require '../../lib/coffee-script/nodes'

parse = (code) -> parser.parse(code)

xexports = {}

exports.Test =
  "test atomic": (test) ->
    test.equal  parse('3'), 3
#    test.equal  parse('123'), 123
#    test.deepEqual  parse('-123.56e-3'), coreSolve(neg(0.12356))
#    test.deepEqual  parse('"1"'), coreSolve(string('"1"'))
#    #    test.equal  solve('a'), a
    test.done()
