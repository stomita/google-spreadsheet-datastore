Spreadsheet = require "edit-google-spreadsheet"
Client = require "./client"
PromiseUtil = require "./promise-util"

###
#
###
class Sheet

  @DEFAULT_REMOVED_STATUS = "DELETED"

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
      PromiseUtil.wait @rawRows, @range, (rawRows, range) =>
        for y in [(range.top + 1)..range.bottom]
          rawRows[y + 1][x + 1] for x in [range.left..range.right]

    @headers = PromiseUtil.lazy =>
      PromiseUtil.wait @rawRows, @range, (rawRows, range) =>
        rawRows[range.top + 1][x + 1] for x in [range.left..range.right]

    @headerMap = PromiseUtil.lazy =>
      @headers.then (headers) ->
        headerMap = {}
        headerMap[header] = i for header, i in headers
        headerMap

    @rowIndex = PromiseUtil.lazy =>
      PromiseUtil.wait @rows, @keyColumnIndex, (rows, keyColumnIndex) =>
        rowIndex = {}
        rowIndex[row[keyColumnIndex]] = i for row, i in rows
        rowIndex

    @keyColumn = PromiseUtil.lazy =>
      if @config.keyColumn
        PromiseUtil.resolve(@config.keyColumn)
      else if @config.keyColumnIndex >= 0
        @headers.then (headers) => headers[@config.keyColumnIndex]
      else
        PromiseUtil.reject new Error("No keyColumn or keyColumnIndex information is found in sheet config.")

    @keyColumnIndex = PromiseUtil.lazy =>
      if @config.keyColumnIndex >= 0
        PromiseUtil.resolve(@config.keyColumnIndex)
      else if @config.keyColumn
        @headerMap.then (headerMap) => headerMap[@config.keyColumn]
      else
        PromiseUtil.reject new Error("No keyColumn or keyColumnIndex information is found in sheet config.")

    @removedStatusColumn = PromiseUtil.lazy =>
      if @config.removedStatusColumn
        PromiseUtil.resolve(@config.removedStatusColumn)
      else if @config.removedStatusColumnIndex >= 0
        @headers.then (headers) => headers[@config.removedStatusColumnIndex]
      else
        PromiseUtil.reject new Error("No removedStatusColumn or removedStatusColumnIndex information is found in sheet config.")

    @removedStatusColumnIndex = PromiseUtil.lazy =>
      if @config.removedStatusColumnIndex >= 0
        PromiseUtil.resolve(@config.removedStatusColumnIndex)
      else if @config.removedStatusColumn
        @headerMap.then (headerMap) => headerMap[@config.removedStatusColumn]
      else
        PromiseUtil.reject new Error("No removedStatusColumn or removedStatusColumnIndex information is found in sheet config.")

    undefined


  metadata: ->
    @spreadsheet.then (ss) =>
      PromiseUtil.async (cb) ->
        ss.metadata(cb)

  count: (conditions = {}, options={}) ->
    @find(conditions, options).then (records) -> records.length

  findByKey: (key, includeRemoved=false) ->
    PromiseUtil.wait @rows, @rowIndexOf(key), @removedStatusColumnIndex, (rows, rowIndex, removedStatusColumnIndex) =>
      row = rows[rowIndex]
      if row
        removedStatus = @config.removedStatus || Sheet.DEFAULT_REMOVED_STATUS
        if !includeRemoved && removedStatusColumnIndex >= 0 && row[removedStatusColumnIndex] == removedStatus
          null
        else
          @toRecord(row)
      else
        null

  findOne: (conditions={}) ->
    @find(conditions, { limit: 1 })
      .then (records) -> records.pop()

  find: (conditions={}, options={}) ->
    offset = options.offset || 0
    limit = options.limit || 100

    PromiseUtil.wait @headerMap, @rows, @removedStatusColumnIndex, (headerMap, rows, removedStatusColumnIndex) =>
      removedStatus = @config.removedStatus || Sheet.DEFAULT_REMOVED_STATUS
      PromiseUtil.all(
        rows.filter (row) =>
          if !options.includeRemoved && removedStatusColumnIndex >= 0 && row[removedStatusColumnIndex] == removedStatus
            return false
          for prop, value of conditions
            propIndex = headerMap[prop]
            if propIndex >= 0 && row[propIndex] != value
              return false
          true
        .slice(offset, offset + limit)
        .map (row) => @toRecord(row)
      )

  insert: (record) ->
    PromiseUtil.wait @spreadsheet, @keyColumn, @count({}, { includeRemoved: true }), (ss, keyColumn, offsetY) =>
      unless keyColumn
        throw new Error "keyColumn is not found either in sheet config or in headers."
      key = record[keyColumn]
      if key && @config.autoGenerateKey 
        throw new Error "Key property is already set even autoGenerateKey option is set to true."
      if !key 
        if !@config.autoGenerateKey
          throw new Error "No key property value is set in record."
        else
          key = @generateUniqueKey()
      @rowIndexOf(key).then (rowIndex) ->
        if rowIndex >= 0
          throw new Error "A record with the key already found in the sheet."
      .then =>
        record[keyColumn] = key
        @toAbsolute(@toRow(record), { y: offsetY + 1 })
      .then (absrow) ->
        ss.add absrow
        PromiseUtil.async (cb) ->
          ss.send { autoSize: true }, (err) -> cb(err)
      .then =>
        @resetData()
        { success: true, key: key }

  update: (key, record) ->
    PromiseUtil.wait @spreadsheet, @rowIndexOf(key), (ss, offsetY) =>
      unless offsetY >= 0
        throw new Error "No record found matching the key: #{key}"
      @toAbsolute(@toRow(record), { y: offsetY + 1 }).then (absrow) ->
        ss.add absrow
        PromiseUtil.async (cb) ->
          ss.send { autoSize: true }, (err) -> cb(err)
      .then =>
        @resetData()
        { success: true, key: key }

  remove: (key) ->
    record = {}
    @removedStatusColumn.then (removedStatusColumn) =>
      unless removedStatusColumn
        throw new Error "removedStatusColumn is not found either in sheet config or in headers."
      removedStatus = @config.removedStatus || Sheet.DEFAULT_REMOVED_STATUS
      record[removedStatusColumn] = removedStatus
      @update(key, record)


  generateUniqueKey: ->
    "key_" + Date.now()

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
    PromiseUtil.wait @range, row, (range, row) =>
      absrow = {}
      yindex = range.top + (offset.y || 0) + 1
      xindex = range.left + (offset.x || 0) + 1
      absrow[yindex] = {}
      absrow[yindex][xindex] = [ row ]
      absrow

  rowIndexOf: (key) ->
    @rowIndex.then (rowIndex) -> rowIndex[key]

module.exports = Sheet

