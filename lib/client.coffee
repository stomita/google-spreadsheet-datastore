fs = require "fs"
querystring = require "querystring"
request = require "request"
PromiseUtil = require "./promise-util"
TokenStore = require "./token-store"

###
#
###
class MemoryStorage
  @tokens = {}

  constructor: (@config, @uid) ->
    @store(@config.tokens) if @config.tokens

  load: ->
    tokens = MemoryStorage.tokens[@config.type + ":" + @uid]
    PromiseUtil.resolve(tokens)

  store: (tokens) ->
    MemoryStorage.tokens[@config.type + ":" + @uid] = tokens
    PromiseUtil.resolve(tokens)

###
#
###
class FileStorage
  constructor: (@config, @uid) ->

  load: ->
    filePath = @config.filePath
    PromiseUtil.async (cb) ->
      fs.readFile(filePath, cb)
    .then (data) ->
      JSON.parse data

  store: (tokens) ->
    filePath = @config.filePath
    data = JSON.stringify(tokens, null, 4)
    PromiseUtil.async (cb) ->
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

  constructor: (config) ->
    name = config.name
    @config = require('./config').clients[name]
    @storageConfig = config.storage || {}
    @tokenStores = {}

  verify: (accessToken) ->
    return PromiseUtil.resolve(false) unless accessToken
    PromiseUtil.async (cb) =>
      request
        method: "GET"
        url: @config.verify_url + "?access_token=" + accessToken
      , cb
    .then (res) ->
      res.statusCode < 400

  refresh: (refreshToken) ->
    PromiseUtil.async (cb) =>
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
    @tokenStores[uid] ||= @createTokenStore(uid)

  createTokenStore: (uid) ->
    Storage = Client.storageClasses[@storageConfig.type] || MemoryStorage
    new TokenStore(@, new Storage(@storageConfig, uid))


module.exports = Client