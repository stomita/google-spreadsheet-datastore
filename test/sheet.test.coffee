assert = require "power-assert"

Sheet = require "../lib/sheet"

describe "sheet", ->

  @timeout 20000

  sheet = new Sheet
    client:
      name: "google"
      storage:
        type: "memory"
        tokens:
          access_token: process.env.GOOGLE_API_ACCESS_TOKEN
          refresh_token: process.env.GOOGLE_API_REFRESH_TOKEN
    spreadsheetId: "1ug9clvNQmMou_FWYzV9pCDi5ex5jeEk0g9dJ-aKzXyc"
    worksheetId: "od6"
    keyColumn: "ID"
    autoGenerateKey: true
    removedStatusColumn: "IS_DELETED"
    removedStatus: "Y"

  it "should find sheet data", ->
    sheet.find().then (records) ->
      assert.ok(records.length >= 80)

  it "should find one record by key", ->
    sheet.findByKey("0018000000Yt1ZDAAZ")
      .then (record) ->
        assert.ok record["ID"] == "0018000000Yt1ZDAAZ"
        assert.ok record["業種"] == "食品卸売"

  it "should get metadata of sheet", ->
    sheet.metadata()
      .then (metadata) ->
        assert.ok(metadata.rowCount > 0)
        assert.ok(metadata.colCount > 0)

  newKey = null

  it "should create new record in the sheet", ->
    sheet.insert(
      "会社名": "テスト取引先"
    )
    .then (ret) ->
      assert ret.success == true
      newKey = ret.key

  it "should update record in the sheet", ->
    sheet.update(newKey,
      "会社名": "★★★ 変更済み取引先 ★★★"
      "従業員数": 2500
    )
    .then (ret) ->
      assert.ok ret.success == true
      assert.ok ret.key == newKey
    .then ->
      sheet.findByKey(newKey)
    .then (record) ->
      assert.ok record["会社名"] == "★★★ 変更済み取引先 ★★★"
      assert.ok record["従業員数"] == 2500

  it "should remove created record in the sheet", ->
    sheet.remove(newKey).then (ret) ->
      assert.ok ret.success == true
      assert.ok ret.key == newKey
    .then ->
      sheet.findByKey(newKey)
    .then (record) ->
      assert.ok record == null


