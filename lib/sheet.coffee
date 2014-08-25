require('source-map-support').install()

Q = require "q"
Spreadsheet = require "edit-google-spreadsheet"
Client = require "./client"

lazyPromise = (fn) ->
  deferred = Q.defer()
  promise = deferred.promise
  evaluated = null
  origThen = promise.then
  promise.then = ->
    unless evaluated
      evaluated = Q.fcall(fn).then (res) ->
        deferred.resolve(res)
      , (err) ->
        deferred.reject(err)
    origThen.apply(promise, arguments)
  promise


###
#
###
class Sheet

  constructor: (@config={}) ->
    client = new Client(@config.client || "google", @config.storage)
    @tokenStore = client.getTokenStore(@config.uid)
    @spreadsheet = lazyPromise =>
      @tokenStore.load(true).then (tokens) =>
        Q.nfcall (cb) =>
          Spreadsheet.load
            spreadsheetId: @config.spreadsheetId
            worksheetId: @config.worksheetId
            accessToken:
              type: 'Bearer'
              token: tokens.access_token
          , (err, res) -> cb(err, res)
    @resetData()

  resetData: ->
    @rawRows = lazyPromise =>
      @spreadsheet.then (ss) ->
        Q.nfcall (cb) -> 
          ss.receive 
            getValues: true
          , (err, res) -> cb(err, res)

    @range = lazyPromise =>
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

    @rows = lazyPromise =>
      Q.all([ @rawRows, @range ]).then (results) ->
        [ rawRows, range ] = results
        for y in [(range.top + 1)..range.bottom]
          rawRows[y + 1][x + 1] for x in [range.left..range.right]

    @headers = lazyPromise =>
      Q.all([ @rawRows, @range ]).then (results) ->
        [ rawRows, range ] = results
        rawRows[range.top + 1][x + 1] for x in [range.left..range.right]

    @headerMap = lazyPromise =>
      @headers.then (headers) ->
        headerMap = {}
        headerMap[header] = i for header, i in headers
        headerMap

    @index = lazyPromise =>
      Q.all([ @headerMap, @rows ]).then (results) =>
        [ headerMap, rows ] = results
        keyIndex = @config.keyIndex || headerMap[@config.keyName] || 0
        index = {}
        index[row[keyIndex]] = i for row, i in rows
        index

  count: (conditions = {}) ->
    @find(conditions).then (records) -> records.length

  metadata: ->
    @spreadsheet.then (ss) =>
      Q.nfcall (cb) -> ss.metadata(cb)

  insert: (record) ->
    Q.all([ @spreadsheet, @count() ]).then (results) =>
      [ ss, offsetY ] = results
      @toAbsolute(@toRow(record), { y: offsetY + 1 }).then (absrow) ->
        ss.add absrow
        Q.nfcall (cb) ->
          ss.send { autoSize: true }, (err, res) ->
            cb(err, res)
      .then (res) =>
        @resetData()

  update: (key, record) ->
    Q.all([ @spreadsheet, @indexOf(key) ]).then (results) =>
      [ ss, offsetY ] = results
      @toAbsolute(@toRow(record), { y: offsetY + 1 }).then (absrow) ->
        ss.add absrow
        Q.nfcall (cb) ->
          ss.send { autoSize: true }, (err, res) -> cb(err, res)
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
    Q.all [ @range, row ]
      .then (results) =>
        [ range, row ] = results
        absrow = {}
        yindex = range.top + (offset.y || 0) + 1
        xindex = range.left + (offset.x || 0) + 1
        absrow[yindex] = {}
        absrow[yindex][xindex] = [ row ]
        absrow

  indexOf: (key) ->
    @index.then (index) -> index[key]

  findByKey: (key) ->
    Q.all [ @rows, @indexOf(key) ]
      .then (results) =>
        [ rows, index ] = results
        row = rows[index]
        if row then @toRecord row else null

  findOne: (conditions={}) ->
    @find(conditions, { limit: 1 })
      .then (records) -> records.pop()

  find: (conditions={}, options={}) ->
    offset = options.offset || 0
    limit = options.limit || 100
    Q.all [ @headerMap, @rows ]
      .then (results) =>
        [ headerMap, rows ] = results
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

