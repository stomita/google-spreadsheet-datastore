(function() {
  var PromiseUtil, TokenStore;

  PromiseUtil = require("./promise-util");


  /*
   *
   */

  TokenStore = (function() {
    function TokenStore(client, storage) {
      this.client = client;
      this.storage = storage;
    }

    TokenStore.prototype.set = function(tokens) {
      return this.tokens = PromiseUtil.resolve(tokens);
    };

    TokenStore.prototype.reset = function() {
      return this.tokens = null;
    };

    TokenStore.prototype.load = function(verify) {
      if (verify == null) {
        verify = false;
      }
      if (!this.tokens) {
        this.tokens = this.storage.load();
      }
      if (verify) {
        return this.verify();
      } else {
        return this.tokens;
      }
    };

    TokenStore.prototype.store = function() {
      if (this.tokens) {
        return this.tokens.then((function(_this) {
          return function(tokens) {
            return _this.storage.store(tokens);
          };
        })(this));
      } else {
        return PromiseUtil.reject(new Error("no token information to store"));
      }
    };

    TokenStore.prototype.verify = function() {
      if (this.tokens) {
        return this.tokens.then((function(_this) {
          return function(tokens) {
            return _this.client.verify(tokens.access_token);
          };
        })(this)).then((function(_this) {
          return function(verified) {
            if (verified) {
              return _this.tokens;
            } else {
              return _this.refresh();
            }
          };
        })(this));
      } else {
        return PromiseUtil.reject(new Error("no token information to verify"));
      }
    };

    TokenStore.prototype.refresh = function() {
      return this.tokens.then(function(tokens) {
        if (!tokens.refresh_token) {
          throw new Error("no refresh token in token store");
        }
        return tokens.refresh_token;
      }).then((function(_this) {
        return function(refreshToken) {
          _this.tokens = _this.client.refresh(refreshToken);
          return _this.store();
        };
      })(this));
    };

    return TokenStore;

  })();

  module.exports = TokenStore;

}).call(this);

//# sourceMappingURL=token-store.js.map
