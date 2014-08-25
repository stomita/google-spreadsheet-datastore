require('source-map-support').install()

fs = require "fs"
querystring = require "querystring"
Q = require "q"
request = require "request"

config = require "./config"

class TokenStore

  constructor: (@name, @config) ->

  load: (verify=false) ->
    unless @tokens
      fileName = "#{TokenStore.basePath}/#{@name}.json"
      @tokens = Q.denodeify(fs.readFile)(fileName).then (data) ->
        JSON.parse data
    if verify then @verify() else @tokens

  store: ->
    if @tokens
      fileName = "#{TokenStore.basePath}/#{@name}.json"
      @tokens.then (tokens) ->
        data = JSON.stringify(tokens, null, 4)
        Q.ninvoke(fs, "writeFile", fileName, data, "utf-8")
          .then -> tokens
    else
      Q.reject(new Error "no token information to store")

  verify: ->
    if @tokens
      @tokens.then (tokens) =>
        Q.nfcall (cb) =>
          request
            method: "GET"
            url: @config.verify_url + "?access_token=#{tokens.access_token}"
          ,
            (err, res) -> cb(err, res)
      .then (res) =>
        if res.statusCode >= 400 then @refresh() else @tokens
    else
      Q.reject(new Error "no token information to verify")


  refresh: ->
    @tokens.then (tokens) ->
      throw new Error "no refresh token in token store" unless tokens.refresh_token
      tokens.refresh_token
    .then (refreshToken) =>
      @tokens = Q.nfcall (cb) =>
        request
          method: "POST"
          url: @config.token_url
          body: querystring.stringify(
            grant_type: "refresh_token"
            refresh_token: refreshToken
            client_id: @config.client_id
            client_secret: @config.client_secret
          )
          headers:
            "content-type": "application/x-www-form-urlencoded"
        ,
          (err, res) -> cb(err, res)
      .then (res) ->
        if res.statusCode >= 400
          error = JSON.parse(res.body)
          throw new Error(error.error + ": " + error.error_description)
        tokens = JSON.parse(res.body)
        tokens.refresh_token = refreshToken
        tokens
      @store()


TokenStore.get = (client) ->
  new TokenStore(client, config.clients[client])

TokenStore.basePath = "."

module.exports = TokenStore