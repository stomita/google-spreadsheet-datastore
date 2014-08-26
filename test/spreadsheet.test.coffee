assert = require "power-assert"

Spreadsheet = require "../lib/spreadsheet"

describe "spreadsheet", ->

  @timeout 20000

  spreadsheet = new Spreadsheet
    id: "1ug9clvNQmMou_FWYzV9pCDi5ex5jeEk0g9dJ-aKzXyc"
    client:
      name: "google"
      storage:
        type: "memory"
        tokens:
          access_token: process.env.GOOGLE_API_ACCESS_TOKEN
          refresh_token: process.env.GOOGLE_API_REFRESH_TOKEN

  it "should list sheets", ->
    spreadsheet.sheets().then (sheets) ->
      assert.ok sheets?.length > 0
      sheets.forEach (sheet) ->
        assert.ok sheet.spreadsheetId == "1ug9clvNQmMou_FWYzV9pCDi5ex5jeEk0g9dJ-aKzXyc"
        assert.ok sheet.worksheetId != null
        assert.ok sheet.title != null


