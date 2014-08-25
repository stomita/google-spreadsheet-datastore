require('source-map-support').install()

fs = require "fs"
querystring = require "querystring"
Q = require "q"
request = require "request"
TokenStore = require "./token-store"

###
#
###
class MemoryStorage
  @tokens = {}

  constructor: (@config, @uid) ->
    console.log @config
    @store(@config.tokens) if @config.tokens

  load: ->
    tokens = MemoryStorage.tokens[@config.type + ":" + @uid]
    Q(tokens)

  store: (tokens) ->
    MemoryStorage.tokens[@config.type + ":" + @uid] = tokens
    Q(tokens)

###
#
###
class FileStorage
  constructor: (@config, @uid) ->

  load: ->
    filePath = @config.filePath
    Q.nfcall (cb) ->
      fs.readFile(filePath, cb)
    .then (data) ->
      JSON.parse data

  store: (tokens) ->
    filePath = @config.filePath
    data = JSON.stringify(tokens, null, 4)
    Q.nfcall (cb) ->
      fs.writeFile(filePath, data, "utf-8", cb)
    .then ->
      tokens

###
#
###
class Client
  @storageClasses = 
    memory: MemoryStorage
    file: FileStorage

  constructor: (name, @storageConfig={}) ->
    @config = require('./config').clients[name]

  verify: (accessToken) ->
    Q.nfcall (cb) =>
      request
        method: "GET"
        url: @config.verify_url + "?access_token=" + accessToken
      , cb
    .then (res) ->
      res.statusCode < 400

  refresh: (refreshToken) ->
    Q.nfcall (cb) =>
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
      , cb
    .then (res) ->
      if res.statusCode >= 400
        error = JSON.parse(res.body)
        throw new Error(error.error + ": " + error.error_description)
      tokens = JSON.parse(res.body)
      tokens.refresh_token = refreshToken
      tokens

  getTokenStore: (uid="default") ->
    Storage = Client.storageClasses[@storageConfig.type] || MemoryStorage
    new TokenStore(@, new Storage(@storageConfig, uid))


module.exports = Client