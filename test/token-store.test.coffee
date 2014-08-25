assert = require "power-assert"

TokenStore = require "../lib/token-store"

TokenStore.basePath = "#{__dirname}/creds"

describe "token store", ->

  it "should load tokens", (done) ->
    @timeout 20000
    ts = TokenStore.get("google")
    ts.load(true).then (tokens) ->
      assert.ok(tokens.access_token)
      done()
    .fail (err) ->
      done(err)



