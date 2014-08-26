assert = require "power-assert"

Client = require "../lib/client"

describe "token store", ->
  @timeout 20000

  it "should load tokens", (done) ->
    client = new Client(name: "google")
    ts = client.getTokenStore()
    ts.set
      access_token: process.env.GOOGLE_API_ACCESS_TOKEN
      refresh_token: process.env.GOOGLE_API_REFRESH_TOKEN
    ts.store()
    ts.load(true).then (tokens) ->
      assert.ok(tokens.access_token)
      done()
    .fail (err) ->
      done(err)



