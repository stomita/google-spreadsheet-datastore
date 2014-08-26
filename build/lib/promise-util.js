(function() {
  var Q;

  Q = require("q");

  module.exports = {
    resolve: function(value) {
      return Q(value);
    },
    reject: function(err) {
      return Q.reject(err);
    },
    all: function(arr) {
      return Q.all(arr);
    },
    wait: function() {
      var args, fn;
      args = Array.prototype.slice.call(arguments);
      fn = args.pop();
      return Q.all(args).then(function(results) {
        return fn.apply(null, results);
      });
    },
    async: function(fn) {
      var deferred;
      deferred = Q.defer();
      fn(function(err, result) {
        if (err) {
          return deferred.reject(err);
        } else {
          return deferred.resolve(result);
        }
      });
      return deferred.promise;
    },
    lazy: function(fn) {
      var deferred, evaluated, origThen, promise;
      deferred = Q.defer();
      promise = deferred.promise;
      evaluated = null;
      origThen = promise.then;
      promise.then = function() {
        if (!evaluated) {
          evaluated = Q.fcall(fn).then(function(res) {
            return deferred.resolve(res);
          }, function(err) {
            return deferred.reject(err);
          });
        }
        return origThen.apply(promise, arguments);
      };
      return promise;
    }
  };

}).call(this);

//# sourceMappingURL=promise-util.js.map
