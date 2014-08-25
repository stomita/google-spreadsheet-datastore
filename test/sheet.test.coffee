assert = require "power-assert"

TokenStore = require "../lib/token-store"
TokenStore.basePath = "#{__dirname}/creds"

Sheet = require "../lib/sheet"

describe "sheet", ->

  @timeout 20000

  sheet = new Sheet
    client: "google"
    storage:
      type: "memory"
      tokens:
        access_token: process.env.GOOGLE_API_ACCESS_TOKEN
        refresh_token: process.env.GOOGLE_API_REFRESH_TOKEN
    spreadsheetId: "1ug9clvNQmMou_FWYzV9pCDi5ex5jeEk0g9dJ-aKzXyc"
    worksheetId: "od6"
    keyIndex: 0

  it "should find sheet data", (done) ->
    sheet.find().then (records) ->
      assert.ok(records.length >= 80)
      done()
    .fail (err) ->
      done(err)

  it "should find one record by key", (done) ->
    sheet.findByKey("0018000000Yt1ZDAAZ")
      .then (record) ->
        assert.ok record["取引先 ID"] == "0018000000Yt1ZDAAZ"
        assert.ok record["業種"] == "食品卸売"
        done()
      .fail (err) ->
        done(err)

  it "should get metadata of sheet", (done) ->
    sheet.metadata()
      .then (metadata) ->
        assert.ok(metadata.rowCount > 0)
        assert.ok(metadata.colCount > 0)
        done()
      .fail (err) ->
        done(err)

  it "should update record in the sheet", (done) ->
    sheet.update("0018000000Yt1Z4AAJ",
      "取引先名": "変更済み取引先"
      "従業員数": 2000
    ).then (res) ->
      done()
    .fail (err) ->
      done(err)


###
  it "should create new record in the sheet", (done) ->
    ts = Date.now()
    sheet.insert(
      "取引先 ID": "test" + ts
      "取引先名": "テスト取引先" + ts
    ).then (res) ->
      done()
    .fail (err) ->
      done(err)
###

