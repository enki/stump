
chai = require 'chai'  
chai.should()
expect = chai.expect
assert = chai.assert
stump = require('../stump')
Q = require('q')

describe 'Stump', ->
  beforeEach ->
    @stump = new stump.StumpLog('bar')

  it 'can log', ->
    @stump.warn('hello')

  it 'can sublog', ->
    sublog = @stump.sub('frob')
    sublog.error('hello')
    @stump.warn('hello')
