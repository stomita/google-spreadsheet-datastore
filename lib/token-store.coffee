Q = require "q"


###
#
###
class TokenStore

  constructor: (@client, @storage) ->

  set: (tokens) ->
    @tokens = Q(tokens)

  reset: ->
    @tokens = null

  load: (verify=false) ->
    @tokens = @storage.load() unless @tokens
    if verify then @verify() else @tokens

  store: ->
    if @tokens
      @tokens.then (tokens) =>
        @storage.store(tokens)
    else
      Q.reject(new Error "no token information to store")

  verify: ->
    if @tokens
      @tokens.then (tokens) =>
        @client.verify tokens.access_token
      .then (verified) =>
        if verified then @refresh() else @tokens
    else
      Q.reject(new Error "no token information to verify")

  refresh: ->
    @tokens.then (tokens) ->
      throw new Error "no refresh token in token store" unless tokens.refresh_token
      tokens.refresh_token
    .then (refreshToken) =>
      @tokens = @client.refresh refreshToken
      @store()


module.exports = TokenStore
