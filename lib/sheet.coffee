require('source-map-support').install()

Spreadsheet = require "edit-google-spreadsheet"
Client = require "./client"
PromiseUtil = require "./promise-util"

###
#
###
class Sheet

  constructor: (@config={}) ->
    client = new Client(@config.client || "google", @config.storage)
    @tokenStore = client.getTokenStore(@config.uid)
    @spreadsheet = PromiseUtil.lazy =>
      @tokenStore.load(true).then (tokens) =>
        PromiseUtil.async (cb) =>
          Spreadsheet.load
            spreadsheetId: @config.spreadsheetId
            worksheetId: @config.worksheetId
            accessToken:
              type: 'Bearer'
              token: tokens.access_token
          , cb
    @resetData()

  resetData: ->
    @rawRows = PromiseUtil.lazy =>
      @spreadsheet.then (ss) ->
        PromiseUtil.async (cb) =>
          ss.receive { getValues: true }, cb

    @range = PromiseUtil.lazy =>
      @rawRows.then (rawRows) ->
        [ top, bottom, left, right ] = [ Infinity, 0, Infinity, 0 ]
        for rindex, row of rawRows
          rindex = parseInt(rindex, 10) - 1
          top = rindex if rindex < top
          bottom = rindex if rindex > bottom
          for cindex, cell of row
            cindex = parseInt(cindex, 10) - 1
            left = cindex if cindex < left
            right = cindex if cindex > right
        range = { top: top, right: right, bottom: bottom, left: left }
        range

    @rows = PromiseUtil.lazy =>
      PromiseUtil.all @rawRows, @range, (rawRows, range) =>
        for y in [(range.top + 1)..range.bottom]
          rawRows[y + 1][x + 1] for x in [range.left..range.right]

    @headers = PromiseUtil.lazy =>
      PromiseUtil.all @rawRows, @range, (rawRows, range) =>
        rawRows[range.top + 1][x + 1] for x in [range.left..range.right]

    @headerMap = PromiseUtil.lazy =>
      @headers.then (headers) ->
        headerMap = {}
        headerMap[header] = i for header, i in headers
        headerMap

    @index = PromiseUtil.lazy =>
      PromiseUtil.all @headerMap, @rows, (headerMap, rows) =>
        keyIndex = @config.keyIndex || headerMap[@config.keyName] || 0
        index = {}
        index[row[keyIndex]] = i for row, i in rows
        index

  count: (conditions = {}) ->
    @find(conditions).then (records) -> records.length

  metadata: ->
    @spreadsheet.then (ss) =>
      PromiseUtil.async (cb) ->
        ss.metadata(cb)

  insert: (record) ->
    PromiseUtil.all @spreadsheet, @count(), (ss, offsetY) =>
      @toAbsolute(@toRow(record), { y: offsetY + 1 }).then (absrow) ->
        ss.add absrow
        PromiseUtil.async (cb) ->
          ss.send { autoSize: true }, cb
      .then (res) =>
        @resetData()

  update: (key, record) ->
    PromiseUtil.all @spreadsheet, @indexOf(key), (ss, offsetY) =>
      @toAbsolute(@toRow(record), { y: offsetY + 1 }).then (absrow) ->
        ss.add absrow
        PromiseUtil.async (cb) ->
          ss.send { autoSize: true }, cb
      .then (res) =>
        @resetData()
        res

  toRecord: (row) ->
    @headers.then (headers) ->
      record = {}
      record[header] = row[i] for header, i in headers
      record

  toRow: (record) ->
    @headers.then (headers) ->
      row = (record[header] for header in headers)
      row

  toAbsolute: (row, offset = {}) ->
    PromiseUtil.all @range, row, (range, row) =>
      absrow = {}
      yindex = range.top + (offset.y || 0) + 1
      xindex = range.left + (offset.x || 0) + 1
      absrow[yindex] = {}
      absrow[yindex][xindex] = [ row ]
      absrow

  indexOf: (key) ->
    @index.then (index) -> index[key]

  findByKey: (key) ->
    PromiseUtil.all @rows, @indexOf(key), (rows, index) =>
      row = rows[index]
      if row then @toRecord(row) else null

  findOne: (conditions={}) ->
    @find(conditions, { limit: 1 })
      .then (records) -> records.pop()

  find: (conditions={}, options={}) ->
    offset = options.offset || 0
    limit = options.limit || 100
    PromiseUtil.all @headerMap, @rows, (headerMap, rows) =>
      rows.filter (row) ->
        valid = true
        for prop, value of conditions
          propIndex = headerMap[prop]
          if propIndex >= 0 && row[propIndex] != value
            valid = false
            break
        valid
      .slice(offset, offset + limit)
      .map (row) => @toRecord row

module.exports = Sheet

