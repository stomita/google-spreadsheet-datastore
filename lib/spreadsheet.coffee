request = require "request"
Client = require "./client"
PromiseUtil = require "./promise-util"

###
#
###
class Spreadsheet
  constructor: (@config) ->
    @client = 
      if @config.client instanceof Client
        @config.client
      else
        new Client(@config.client)
    @tokenStore = @client.getTokenStore(@config.uid)

  sheets: ->
    @tokenStore.load(true).then (tokens) =>
      PromiseUtil.async (cb) =>
        request
          method: "GET"
          url: "https://spreadsheets.google.com/feeds/worksheets/#{@config.id}/private/full?alt=json"
          headers:
            Authorization: "Bearer #{tokens.access_token}"
        , cb
    .then (res) =>
      if res.statusCode >= 400
        throw new Error "Error in retrieving sheet: status=#{res.statusCode}\n#{res.body}"
      result = JSON.parse(res.body)
      result.feed.entry.map (sheet) =>
        {
          spreadsheetId: @config.id
          worksheetId: sheet.id?.$t?.split("/").pop()
          title: sheet.title?.$t
        }

module.exports = Spreadsheet



