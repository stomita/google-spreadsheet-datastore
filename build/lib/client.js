(function() {
  var Client, FileStorage, MemoryStorage, PromiseUtil, TokenStore, fs, querystring, request;

  fs = require("fs");

  querystring = require("querystring");

  request = require("request");

  PromiseUtil = require("./promise-util");

  TokenStore = require("./token-store");


  /*
   *
   */

  MemoryStorage = (function() {
    MemoryStorage.tokens = {};

    function MemoryStorage(config, uid) {
      this.config = config;
      this.uid = uid;
      if (this.config.tokens) {
        this.store(this.config.tokens);
      }
    }

    MemoryStorage.prototype.load = function() {
      var tokens;
      tokens = MemoryStorage.tokens[this.config.type + ":" + this.uid];
      return PromiseUtil.resolve(tokens);
    };

    MemoryStorage.prototype.store = function(tokens) {
      MemoryStorage.tokens[this.config.type + ":" + this.uid] = tokens;
      return PromiseUtil.resolve(tokens);
    };

    return MemoryStorage;

  })();


  /*
   *
   */

  FileStorage = (function() {
    function FileStorage(config, uid) {
      this.config = config;
      this.uid = uid;
    }

    FileStorage.prototype.load = function() {
      var filePath;
      filePath = this.config.filePath;
      return PromiseUtil.async(function(cb) {
        return fs.readFile(filePath, cb);
      }).then(function(data) {
        return JSON.parse(data);
      });
    };

    FileStorage.prototype.store = function(tokens) {
      var data, filePath;
      filePath = this.config.filePath;
      data = JSON.stringify(tokens, null, 4);
      return PromiseUtil.async(function(cb) {
        return fs.writeFile(filePath, data, "utf-8", cb);
      }).then(function() {
        return tokens;
      });
    };

    return FileStorage;

  })();


  /*
   *
   */

  Client = (function() {
    Client.storageClasses = {
      memory: MemoryStorage,
      file: FileStorage
    };

    function Client(config) {
      var name;
      name = config.name;
      this.config = require('./config').clients[name];
      this.storageConfig = config.storage || {};
      this.tokenStores = {};
    }

    Client.prototype.verify = function(accessToken) {
      if (!accessToken) {
        return PromiseUtil.resolve(false);
      }
      return PromiseUtil.async((function(_this) {
        return function(cb) {
          return request({
            method: "GET",
            url: _this.config.verify_url + "?access_token=" + accessToken
          }, cb);
        };
      })(this)).then(function(res) {
        return res.statusCode < 400;
      });
    };

    Client.prototype.refresh = function(refreshToken) {
      return PromiseUtil.async((function(_this) {
        return function(cb) {
          return request({
            method: "POST",
            url: _this.config.token_url,
            body: querystring.stringify({
              grant_type: "refresh_token",
              refresh_token: refreshToken,
              client_id: _this.config.client_id,
              client_secret: _this.config.client_secret
            }),
            headers: {
              "content-type": "application/x-www-form-urlencoded"
            }
          }, cb);
        };
      })(this)).then(function(res) {
        var error, tokens;
        if (res.statusCode >= 400) {
          error = JSON.parse(res.body);
          throw new Error(error.error + ": " + error.error_description);
        }
        tokens = JSON.parse(res.body);
        tokens.refresh_token = refreshToken;
        return tokens;
      });
    };

    Client.prototype.getTokenStore = function(uid) {
      var _base;
      if (uid == null) {
        uid = "default";
      }
      return (_base = this.tokenStores)[uid] || (_base[uid] = this.createTokenStore(uid));
    };

    Client.prototype.createTokenStore = function(uid) {
      var Storage;
      Storage = Client.storageClasses[this.storageConfig.type] || MemoryStorage;
      return new TokenStore(this, new Storage(this.storageConfig, uid));
    };

    return Client;

  })();

  module.exports = Client;

}).call(this);

//# sourceMappingURL=client.js.map
