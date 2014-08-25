Q = require "q"

module.exports =
  resolve: (value) -> Q(value)

  reject: (err) -> Q.reject(err)
  
  all: () ->
    args = Array.prototype.slice.call arguments
    fn = args.pop()
    Q.all(args).then (results) ->
      fn.apply(null, results)

  async: (fn) ->
    deferred = Q.defer()
    fn (err, result) ->
      if err
        deferred.reject(err)
      else
        deferred.resolve(result)
    deferred.promise

  lazy: (fn) ->
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

