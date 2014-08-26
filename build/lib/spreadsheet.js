(function() {
  var Client, PromiseUtil, Spreadsheet, request;

  request = require("request");

  Client = require("./client");

  PromiseUtil = require("./promise-util");


  /*
   *
   */

  Spreadsheet = (function() {
    function Spreadsheet(config) {
      this.config = config;
      this.client = this.config.client instanceof Client ? this.config.client : new Client(this.config.client);
      this.tokenStore = this.client.getTokenStore(this.config.uid);
    }

    Spreadsheet.prototype.sheets = function() {
      return this.tokenStore.load(true).then((function(_this) {
        return function(tokens) {
          return PromiseUtil.async(function(cb) {
            return request({
              method: "GET",
              url: "https://spreadsheets.google.com/feeds/worksheets/" + _this.config.id + "/private/full?alt=json",
              headers: {
                Authorization: "Bearer " + tokens.access_token
              }
            }, cb);
          });
        };
      })(this)).then((function(_this) {
        return function(res) {
          var result;
          if (res.statusCode >= 400) {
            throw new Error("Error in retrieving sheet: status=" + res.statusCode + "\n" + res.body);
          }
          result = JSON.parse(res.body);
          return result.feed.entry.map(function(sheet) {
            var _ref, _ref1, _ref2;
            return {
              spreadsheetId: _this.config.id,
              worksheetId: (_ref = sheet.id) != null ? (_ref1 = _ref.$t) != null ? _ref1.split("/").pop() : void 0 : void 0,
              title: (_ref2 = sheet.title) != null ? _ref2.$t : void 0
            };
          });
        };
      })(this));
    };

    return Spreadsheet;

  })();

  module.exports = Spreadsheet;

}).call(this);

//# sourceMappingURL=spreadsheet.js.map
