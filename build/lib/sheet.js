(function() {
  var Client, GoogleSpreadsheet, PromiseUtil, Sheet;

  GoogleSpreadsheet = require("edit-google-spreadsheet");

  Client = require("./client");

  PromiseUtil = require("./promise-util");


  /*
   *
   */

  Sheet = (function() {
    Sheet.DEFAULT_REMOVED_STATUS = "DELETED";

    function Sheet(config) {
      var client;
      this.config = config != null ? config : {};
      client = this.config.client instanceof Client ? this.config.client : new Client(this.config.client);
      this.tokenStore = client.getTokenStore(this.config.uid);
      this.googleSpreadsheet = PromiseUtil.lazy((function(_this) {
        return function() {
          return _this.tokenStore.load(true).then(function(tokens) {
            return PromiseUtil.async(function(cb) {
              return GoogleSpreadsheet.load({
                spreadsheetId: _this.config.spreadsheetId,
                worksheetId: _this.config.worksheetId,
                accessToken: {
                  type: 'Bearer',
                  token: tokens.access_token
                }
              }, cb);
            });
          });
        };
      })(this));
      this.resetData();
    }

    Sheet.prototype.resetData = function() {
      this.rawRows = PromiseUtil.lazy((function(_this) {
        return function() {
          return _this.googleSpreadsheet.then(function(ss) {
            return PromiseUtil.async((function(_this) {
              return function(cb) {
                return ss.receive({
                  getValues: true
                }, cb);
              };
            })(this));
          });
        };
      })(this));
      this.range = PromiseUtil.lazy((function(_this) {
        return function() {
          return _this.rawRows.then(function(rawRows) {
            var bottom, cell, cindex, left, range, right, rindex, row, top, _ref;
            _ref = [Infinity, 0, Infinity, 0], top = _ref[0], bottom = _ref[1], left = _ref[2], right = _ref[3];
            for (rindex in rawRows) {
              row = rawRows[rindex];
              rindex = parseInt(rindex, 10) - 1;
              if (rindex < top) {
                top = rindex;
              }
              if (rindex > bottom) {
                bottom = rindex;
              }
              for (cindex in row) {
                cell = row[cindex];
                cindex = parseInt(cindex, 10) - 1;
                if (cindex < left) {
                  left = cindex;
                }
                if (cindex > right) {
                  right = cindex;
                }
              }
            }
            range = {
              top: top,
              right: right,
              bottom: bottom,
              left: left
            };
            return range;
          });
        };
      })(this));
      this.rows = PromiseUtil.lazy((function(_this) {
        return function() {
          return PromiseUtil.wait(_this.rawRows, _this.range, function(rawRows, range) {
            var x, y, _i, _ref, _ref1, _results;
            _results = [];
            for (y = _i = _ref = range.top + 1, _ref1 = range.bottom; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; y = _ref <= _ref1 ? ++_i : --_i) {
              _results.push((function() {
                var _j, _ref2, _ref3, _results1;
                _results1 = [];
                for (x = _j = _ref2 = range.left, _ref3 = range.right; _ref2 <= _ref3 ? _j <= _ref3 : _j >= _ref3; x = _ref2 <= _ref3 ? ++_j : --_j) {
                  _results1.push(rawRows[y + 1][x + 1]);
                }
                return _results1;
              })());
            }
            return _results;
          });
        };
      })(this));
      this.headers = PromiseUtil.lazy((function(_this) {
        return function() {
          return PromiseUtil.wait(_this.rawRows, _this.range, function(rawRows, range) {
            var x, _i, _ref, _ref1, _results;
            _results = [];
            for (x = _i = _ref = range.left, _ref1 = range.right; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; x = _ref <= _ref1 ? ++_i : --_i) {
              _results.push(rawRows[range.top + 1][x + 1]);
            }
            return _results;
          });
        };
      })(this));
      this.headerMap = PromiseUtil.lazy((function(_this) {
        return function() {
          return _this.headers.then(function(headers) {
            var header, headerMap, i, _i, _len;
            headerMap = {};
            for (i = _i = 0, _len = headers.length; _i < _len; i = ++_i) {
              header = headers[i];
              headerMap[header] = i;
            }
            return headerMap;
          });
        };
      })(this));
      this.rowIndex = PromiseUtil.lazy((function(_this) {
        return function() {
          return PromiseUtil.wait(_this.rows, _this.keyColumnIndex, function(rows, keyColumnIndex) {
            var i, row, rowIndex, _i, _len;
            rowIndex = {};
            for (i = _i = 0, _len = rows.length; _i < _len; i = ++_i) {
              row = rows[i];
              rowIndex[row[keyColumnIndex]] = i;
            }
            return rowIndex;
          });
        };
      })(this));
      this.keyColumn = PromiseUtil.lazy((function(_this) {
        return function() {
          if (_this.config.keyColumn) {
            return PromiseUtil.resolve(_this.config.keyColumn);
          } else if (_this.config.keyColumnIndex >= 0) {
            return _this.headers.then(function(headers) {
              return headers[_this.config.keyColumnIndex];
            });
          } else {
            return PromiseUtil.reject(new Error("No keyColumn or keyColumnIndex information is found in sheet config."));
          }
        };
      })(this));
      this.keyColumnIndex = PromiseUtil.lazy((function(_this) {
        return function() {
          if (_this.config.keyColumnIndex >= 0) {
            return PromiseUtil.resolve(_this.config.keyColumnIndex);
          } else if (_this.config.keyColumn) {
            return _this.headerMap.then(function(headerMap) {
              return headerMap[_this.config.keyColumn];
            });
          } else {
            return PromiseUtil.reject(new Error("No keyColumn or keyColumnIndex information is found in sheet config."));
          }
        };
      })(this));
      this.removedStatusColumn = PromiseUtil.lazy((function(_this) {
        return function() {
          if (_this.config.removedStatusColumn) {
            return PromiseUtil.resolve(_this.config.removedStatusColumn);
          } else if (_this.config.removedStatusColumnIndex >= 0) {
            return _this.headers.then(function(headers) {
              return headers[_this.config.removedStatusColumnIndex];
            });
          } else {
            return PromiseUtil.reject(new Error("No removedStatusColumn or removedStatusColumnIndex information is found in sheet config."));
          }
        };
      })(this));
      this.removedStatusColumnIndex = PromiseUtil.lazy((function(_this) {
        return function() {
          if (_this.config.removedStatusColumnIndex >= 0) {
            return PromiseUtil.resolve(_this.config.removedStatusColumnIndex);
          } else if (_this.config.removedStatusColumn) {
            return _this.headerMap.then(function(headerMap) {
              return headerMap[_this.config.removedStatusColumn];
            });
          } else {
            return PromiseUtil.reject(new Error("No removedStatusColumn or removedStatusColumnIndex information is found in sheet config."));
          }
        };
      })(this));
      return void 0;
    };

    Sheet.prototype.metadata = function() {
      return this.googleSpreadsheet.then((function(_this) {
        return function(ss) {
          return PromiseUtil.async(function(cb) {
            return ss.metadata(cb);
          });
        };
      })(this));
    };

    Sheet.prototype.count = function(conditions, options) {
      if (conditions == null) {
        conditions = {};
      }
      if (options == null) {
        options = {};
      }
      return this.find(conditions, options).then(function(records) {
        return records.length;
      });
    };

    Sheet.prototype.findByKey = function(key, includeRemoved) {
      if (includeRemoved == null) {
        includeRemoved = false;
      }
      return PromiseUtil.wait(this.rows, this.rowIndexOf(key), this.removedStatusColumnIndex, (function(_this) {
        return function(rows, rowIndex, removedStatusColumnIndex) {
          var removedStatus, row;
          row = rows[rowIndex];
          if (row) {
            removedStatus = _this.config.removedStatus || Sheet.DEFAULT_REMOVED_STATUS;
            if (!includeRemoved && removedStatusColumnIndex >= 0 && row[removedStatusColumnIndex] === removedStatus) {
              return null;
            } else {
              return _this.toRecord(row);
            }
          } else {
            return null;
          }
        };
      })(this));
    };

    Sheet.prototype.findOne = function(conditions) {
      if (conditions == null) {
        conditions = {};
      }
      return this.find(conditions, {
        limit: 1
      }).then(function(records) {
        return records.pop();
      });
    };

    Sheet.prototype.find = function(conditions, options) {
      var limit, offset;
      if (conditions == null) {
        conditions = {};
      }
      if (options == null) {
        options = {};
      }
      offset = options.offset || 0;
      limit = options.limit || 100;
      return PromiseUtil.wait(this.headerMap, this.rows, this.removedStatusColumnIndex, (function(_this) {
        return function(headerMap, rows, removedStatusColumnIndex) {
          var removedStatus;
          removedStatus = _this.config.removedStatus || Sheet.DEFAULT_REMOVED_STATUS;
          return PromiseUtil.all(rows.filter(function(row) {
            var prop, propIndex, value;
            if (!options.includeRemoved && removedStatusColumnIndex >= 0 && row[removedStatusColumnIndex] === removedStatus) {
              return false;
            }
            for (prop in conditions) {
              value = conditions[prop];
              propIndex = headerMap[prop];
              if (propIndex >= 0 && row[propIndex] !== value) {
                return false;
              }
            }
            return true;
          }).slice(offset, offset + limit).map(function(row) {
            return _this.toRecord(row);
          }));
        };
      })(this));
    };

    Sheet.prototype.insert = function(record) {
      return PromiseUtil.wait(this.googleSpreadsheet, this.keyColumn, this.count({}, {
        includeRemoved: true
      }), (function(_this) {
        return function(ss, keyColumn, offsetY) {
          var key;
          if (!keyColumn) {
            throw new Error("keyColumn is not found either in sheet config or in headers.");
          }
          key = record[keyColumn];
          if (key && _this.config.autoGenerateKey) {
            throw new Error("Key property is already set even autoGenerateKey option is set to true.");
          }
          if (!key) {
            if (!_this.config.autoGenerateKey) {
              throw new Error("No key property value is set in record.");
            } else {
              key = _this.generateUniqueKey();
            }
          }
          return _this.rowIndexOf(key).then(function(rowIndex) {
            if (rowIndex >= 0) {
              throw new Error("A record with the key already found in the sheet.");
            }
          }).then(function() {
            record[keyColumn] = key;
            return _this.toAbsolute(_this.toRow(record), {
              y: offsetY + 1
            });
          }).then(function(absrow) {
            ss.add(absrow);
            return PromiseUtil.async(function(cb) {
              return ss.send({
                autoSize: true
              }, function(err) {
                return cb(err);
              });
            });
          }).then(function() {
            _this.resetData();
            return {
              success: true,
              key: key
            };
          });
        };
      })(this));
    };

    Sheet.prototype.update = function(key, record) {
      return PromiseUtil.wait(this.googleSpreadsheet, this.rowIndexOf(key), (function(_this) {
        return function(ss, offsetY) {
          if (!(offsetY >= 0)) {
            throw new Error("No record found matching the key: " + key);
          }
          return _this.toAbsolute(_this.toRow(record), {
            y: offsetY + 1
          }).then(function(absrow) {
            ss.add(absrow);
            return PromiseUtil.async(function(cb) {
              return ss.send({
                autoSize: true
              }, function(err) {
                return cb(err);
              });
            });
          }).then(function() {
            _this.resetData();
            return {
              success: true,
              key: key
            };
          });
        };
      })(this));
    };

    Sheet.prototype.remove = function(key) {
      var record;
      record = {};
      return this.removedStatusColumn.then((function(_this) {
        return function(removedStatusColumn) {
          var removedStatus;
          if (!removedStatusColumn) {
            throw new Error("removedStatusColumn is not found either in sheet config or in headers.");
          }
          removedStatus = _this.config.removedStatus || Sheet.DEFAULT_REMOVED_STATUS;
          record[removedStatusColumn] = removedStatus;
          return _this.update(key, record);
        };
      })(this));
    };

    Sheet.prototype.generateUniqueKey = function() {
      return "key_" + Date.now();
    };

    Sheet.prototype.toRecord = function(row) {
      return this.headers.then(function(headers) {
        var header, i, record, _i, _len;
        record = {};
        for (i = _i = 0, _len = headers.length; _i < _len; i = ++_i) {
          header = headers[i];
          record[header] = row[i];
        }
        return record;
      });
    };

    Sheet.prototype.toRow = function(record) {
      return this.headers.then(function(headers) {
        var header, row;
        row = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = headers.length; _i < _len; _i++) {
            header = headers[_i];
            _results.push(record[header]);
          }
          return _results;
        })();
        return row;
      });
    };

    Sheet.prototype.toAbsolute = function(row, offset) {
      if (offset == null) {
        offset = {};
      }
      return PromiseUtil.wait(this.range, row, (function(_this) {
        return function(range, row) {
          var absrow, xindex, yindex;
          absrow = {};
          yindex = range.top + (offset.y || 0) + 1;
          xindex = range.left + (offset.x || 0) + 1;
          absrow[yindex] = {};
          absrow[yindex][xindex] = [row];
          return absrow;
        };
      })(this));
    };

    Sheet.prototype.rowIndexOf = function(key) {
      return this.rowIndex.then(function(rowIndex) {
        return rowIndex[key];
      });
    };

    return Sheet;

  })();

  module.exports = Sheet;

}).call(this);

//# sourceMappingURL=sheet.js.map
